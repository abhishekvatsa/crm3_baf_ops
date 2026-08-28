import {isFiveDigitChargeNumber} from "../chargeNumber";
import {WorkflowError} from "./errors";
import {CommandHandler} from "./handlerTypes";
import {JsonMap, RoleKey} from "./types";
import {cleanText, iso, persistedInstantText, stableJson} from "./utils";
import {
  buildInspectionTargetPopulation,
  inspectionPopulationCounts,
  inspectionTargetKey,
  inspectionTargetPopulationJson,
  markInspectionTargetObserved,
  parseInspectionTargetPopulation,
} from "./inspectionPopulation";

const definitionPath = (id: string): string => `inspection_definitions/${id}`;
const definitionAuditPath = (id: string): string => `inspection_definition_audits/${id}`;
const campaignPath = (id: string): string => `inspection_campaigns/${id}`;
const campaignAuditPath = (id: string): string => `inspection_campaign_audits/${id}`;
const observationPath = (id: string): string => `inspection_observations/${id}`;
const issueLinkPath = (id: string): string => `inspection_issue_links/${id}`;

const VALUE_TYPES = new Set(["number", "boolean", "text", "choice"]);
const ASSET_TYPES = new Set([
  "base", "furnace", "forceCooler", "innerCover", "governedCustom",
]);
const OBSERVER_ROLES = new Set<RoleKey>([
  "admin", "si", "contractSupervisor", "shiftSupervisor", "operations",
  "seniorElectrical", "seniorMechanical", "seniorInstrumentation",
  "refractory", "seniorRefractory",
]);

const exactKeys = (value: JsonMap, expected: readonly string[], field: string): void => {
  if (Object.keys(value).sort().join(",") !== [...expected].sort().join(",")) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} has unsupported or missing fields.`,
      {reasonCode: "inspection-shape-invalid", field},
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

const optionalDocumentId = (value: unknown, field: string): string | null =>
  value == null ? null : documentId(value, field);

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

const stringList = (
  value: unknown,
  field: string,
  maximumItems: number,
  maximumLength: number,
  allowEmpty = true,
): string[] => {
  if (!Array.isArray(value) || value.length > maximumItems ||
      (!allowEmpty && value.length === 0) ||
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

const integerList = (
  value: unknown,
  field: string,
  maximumItems: number,
): number[] => {
  if (!Array.isArray(value) || value.length > maximumItems ||
      value.some((item) => !Number.isSafeInteger(item) || (item as number) < 1)) {
    throw new WorkflowError("invalid-argument", `${field} is invalid.`);
  }
  const parsed = value as number[];
  if (new Set(parsed).size !== parsed.length) {
    throw new WorkflowError("invalid-argument", `${field} contains duplicates.`);
  }
  return [...parsed].sort((a, b) => a - b);
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

const optionalNumber = (value: unknown, field: string): number | null => {
  if (value == null) return null;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new WorkflowError("invalid-argument", `${field} must be a finite number or null.`);
  }
  return value;
};

interface ParsedInspectionDefinition {
  readonly code: string;
  readonly title: string;
  readonly description: string;
  readonly assetTypeKeys: readonly string[];
  readonly assetClassIds: readonly string[];
  readonly componentNodeIds: readonly string[];
  readonly valueType: string;
  readonly unit: string | null;
  readonly choiceValues: readonly string[];
  readonly minimumValue: number | null;
  readonly maximumValue: number | null;
  readonly preconditions: readonly string[];
  readonly requiresChargeNo: boolean;
}

const parseDefinition = (value: unknown): ParsedInspectionDefinition => {
  const data = record(value, "definition");
  exactKeys(data, [
    "schemaVersion", "code", "title", "description", "assetTypeKeys",
    "assetClassIds", "componentNodeIds", "valueType", "unit",
    "choiceValues", "minimumValue", "maximumValue", "preconditions",
    "requiresChargeNo",
  ], "definition");
  if (data.schemaVersion !== 1) {
    throw new WorkflowError("invalid-argument", "definition.schemaVersion is unsupported.");
  }
  const code = boundedText(data.code, "definition.code", 2, 48).toUpperCase();
  if (!/^[A-Z0-9][A-Z0-9_-]+$/.test(code)) {
    throw new WorkflowError("invalid-argument", "definition.code is invalid.");
  }
  const assetTypeKeys = stringList(data.assetTypeKeys, "definition.assetTypeKeys", 10, 48);
  const assetClassIds = stringList(data.assetClassIds, "definition.assetClassIds", 30, 160);
  if (assetTypeKeys.length === 0 && assetClassIds.length === 0) {
    throw new WorkflowError("invalid-argument", "An inspection definition needs an asset scope.");
  }
  if (assetTypeKeys.some((item) => !ASSET_TYPES.has(item))) {
    throw new WorkflowError("invalid-argument", "definition.assetTypeKeys is unsupported.");
  }
  const valueType = cleanText(data.valueType, "definition.valueType");
  if (!VALUE_TYPES.has(valueType)) {
    throw new WorkflowError("invalid-argument", "definition.valueType is unsupported.");
  }
  const unit = optionalText(data.unit, "definition.unit", 40);
  const choiceValues = stringList(data.choiceValues, "definition.choiceValues", 30, 120);
  if ((valueType === "choice") !== (choiceValues.length > 0)) {
    throw new WorkflowError(
      "invalid-argument",
      "Choice inspections require choices; other value types must not provide them.",
    );
  }
  if (valueType === "number" && unit == null) {
    throw new WorkflowError("invalid-argument", "Numeric inspections require a unit.");
  }
  if (valueType !== "number" && unit != null) {
    throw new WorkflowError("invalid-argument", "Only numeric inspections may define a unit.");
  }
  const minimumValue = optionalNumber(data.minimumValue, "definition.minimumValue");
  const maximumValue = optionalNumber(data.maximumValue, "definition.maximumValue");
  if (valueType !== "number" && (minimumValue != null || maximumValue != null)) {
    throw new WorkflowError("invalid-argument", "Only numeric inspections may define limits.");
  }
  if (minimumValue != null && maximumValue != null && minimumValue > maximumValue) {
    throw new WorkflowError("invalid-argument", "minimumValue cannot exceed maximumValue.");
  }
  if (typeof data.requiresChargeNo !== "boolean") {
    throw new WorkflowError("invalid-argument", "definition.requiresChargeNo must be boolean.");
  }
  return {
    code,
    title: boundedText(data.title, "definition.title", 1, 160),
    description: boundedText(data.description, "definition.description", 1, 1000),
    assetTypeKeys,
    assetClassIds,
    componentNodeIds: stringList(data.componentNodeIds, "definition.componentNodeIds", 100, 160),
    valueType,
    unit,
    choiceValues,
    minimumValue,
    maximumValue,
    preconditions: stringList(data.preconditions, "definition.preconditions", 30, 240),
    requiresChargeNo: data.requiresChargeNo,
  };
};

const definitionSnapshot = (data: JsonMap): JsonMap => ({
  schemaVersion: 1,
  definitionId: data.definitionId,
  definitionVersion: data.version,
  code: data.code,
  title: data.title,
  description: data.description,
  assetTypeKeys: data.assetTypeKeys,
  assetClassIds: data.assetClassIds,
  componentNodeIds: data.componentNodeIds,
  valueType: data.valueType,
  unit: data.unit ?? null,
  choiceValues: data.choiceValues,
  minimumValue: data.minimumValue ?? null,
  maximumValue: data.maximumValue ?? null,
  preconditions: data.preconditions,
  requiresChargeNo: data.requiresChargeNo,
});

const writeAudit = (args: {
  readonly tx: Parameters<CommandHandler>[0]["tx"];
  readonly path: string;
  readonly entityId: string;
  readonly operation: string;
  readonly actorUid: string;
  readonly actorName: string;
  readonly at: string;
  readonly reason: string;
  readonly before: JsonMap;
  readonly after: JsonMap;
}): void => args.tx.create(args.path, {
  schemaVersion: 1,
  auditId: args.path.split("/").at(-1)!,
  entityId: args.entityId,
  operation: args.operation,
  performedByUid: args.actorUid,
  performedByName: args.actorName,
  performedAt: args.at,
  reason: args.reason,
  beforeJson: stableJson(args.before),
  afterJson: stableJson(args.after),
});

export const upsertInspectionDefinition: CommandHandler = async ({tx, command, context}) => {
  exactKeys(command.payload, ["definition", "reason"], "payload");
  const id = documentId(command.aggregateId, "aggregateId");
  const parsed = parseDefinition(command.payload.definition);
  const reason = boundedText(command.payload.reason, "reason", 1, 500);
  const [current, codeRows, audit, ...references] = await Promise.all([
    tx.get(definitionPath(id)),
    tx.query("inspection_definitions", [
      {field: "normalizedCode", op: "==", value: parsed.code},
    ]),
    tx.get(definitionAuditPath(command.commandId)),
    ...parsed.assetClassIds.map((classId) => tx.get(`asset_classes/${classId}`)),
    ...parsed.componentNodeIds.map((nodeId) => tx.get(`asset_hierarchy_nodes/${nodeId}`)),
  ]);
  const currentVersion = current.exists && current.data != null &&
      Number.isSafeInteger(current.data.version) ? current.data.version as number : 0;
  if (currentVersion !== command.expectedVersion) {
    throw new WorkflowError("aborted", "The inspection definition changed before this request.");
  }
  if (audit.exists) {
    throw new WorkflowError("failed-precondition", "Inspection-definition audit evidence is orphaned.");
  }
  if (codeRows.some((row) => row.path !== definitionPath(id))) {
    throw new WorkflowError("already-exists", "Another inspection definition uses this code.");
  }
  const classReferences = references.slice(0, parsed.assetClassIds.length);
  const nodeReferences = references.slice(parsed.assetClassIds.length);
  for (let index = 0; index < classReferences.length; index += 1) {
    if (!classReferences[index].exists || classReferences[index].data?.status !== "active" ||
        classReferences[index].data?.assetClassId !== parsed.assetClassIds[index]) {
      throw new WorkflowError("failed-precondition", "An inspection asset class is inactive or missing.");
    }
  }
  for (let index = 0; index < nodeReferences.length; index += 1) {
    const node = nodeReferences[index].data;
    if (!nodeReferences[index].exists || node == null || node.status !== "active" ||
        node.nodeId !== parsed.componentNodeIds[index] ||
        !["component", "subcomponent"].includes(String(node.nodeType)) ||
        typeof node.assetClassId !== "string") {
      throw new WorkflowError("failed-precondition", "An inspection component is inactive or missing.");
    }
  }
  const nodeClassIds = [...new Set(nodeReferences.map((item) =>
    item.data?.assetClassId as string))];
  const nodeClassSnapshots = await Promise.all(
    nodeClassIds.map((classId) => tx.get(`asset_classes/${classId}`)),
  );
  const nodeClasses = new Map(nodeClassIds.map((classId, index) => [
    classId,
    nodeClassSnapshots[index],
  ]));
  for (const nodeReference of nodeReferences) {
    const nodeClassId = nodeReference.data?.assetClassId as string;
    const nodeClass = nodeClasses.get(nodeClassId);
    const inExplicitClassScope = parsed.assetClassIds.includes(nodeClassId);
    const inLegacyTypeScope = nodeClass?.exists === true &&
      nodeClass.data?.status === "active" &&
      typeof nodeClass.data.legacyAssetTypeKey === "string" &&
      parsed.assetTypeKeys.includes(nodeClass.data.legacyAssetTypeKey);
    if (nodeClass?.exists !== true || nodeClass.data?.status !== "active" ||
        (!inExplicitClassScope && !inLegacyTypeScope)) {
      throw new WorkflowError(
        "failed-precondition",
        "An inspection component is outside the definition's asset scope.",
      );
    }
  }
  const now = iso(context.serverNow);
  const nextVersion = currentVersion + 1;
  const after: JsonMap = {
    schemaVersion: 1,
    definitionId: id,
    version: nextVersion,
    status: current.data?.status === "retired" ? "retired" : "active",
    normalizedCode: parsed.code,
    code: parsed.code,
    title: parsed.title,
    description: parsed.description,
    assetTypeKeys: parsed.assetTypeKeys,
    assetClassIds: parsed.assetClassIds,
    componentNodeIds: parsed.componentNodeIds,
    valueType: parsed.valueType,
    unit: parsed.unit,
    choiceValues: parsed.choiceValues,
    minimumValue: parsed.minimumValue,
    maximumValue: parsed.maximumValue,
    preconditions: parsed.preconditions,
    requiresChargeNo: parsed.requiresChargeNo,
    createdAt: current.data?.createdAt ?? now,
    createdByUid: current.data?.createdByUid ?? context.actor.uid,
    createdByName: current.data?.createdByName ?? context.actor.name,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  };
  if (current.exists) tx.update(definitionPath(id), after);
  else tx.create(definitionPath(id), after);
  writeAudit({
    tx,
    path: definitionAuditPath(command.commandId),
    entityId: id,
    operation: current.exists ? "update" : "create",
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason,
    before: current.data ?? {},
    after,
  });
  return {
    resultKey: current.exists ? "inspection-definition-updated" : "inspection-definition-created",
    aggregateVersion: nextVersion,
    result: {definitionId: id, code: parsed.code, status: after.status},
  };
};

export const setInspectionDefinitionStatus: CommandHandler = async ({tx, command, context}) => {
  exactKeys(command.payload, ["status", "reason"], "payload");
  const id = documentId(command.aggregateId, "aggregateId");
  const status = cleanText(command.payload.status, "status");
  if (!["active", "retired"].includes(status)) {
    throw new WorkflowError("invalid-argument", "status is unsupported.");
  }
  const reason = boundedText(command.payload.reason, "reason", 1, 500);
  const [current, audit] = await Promise.all([
    tx.get(definitionPath(id)),
    tx.get(definitionAuditPath(command.commandId)),
  ]);
  if (!current.exists || current.data == null) {
    throw new WorkflowError("not-found", "Inspection definition was not found.");
  }
  if (current.data.version !== command.expectedVersion) {
    throw new WorkflowError("aborted", "The inspection definition changed before this request.");
  }
  if (current.data.status === status || audit.exists) {
    throw new WorkflowError("failed-precondition", "The requested definition transition is not valid.");
  }
  const now = iso(context.serverNow);
  const nextVersion = command.expectedVersion + 1;
  const update: JsonMap = {
    status,
    version: nextVersion,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  };
  tx.update(definitionPath(id), update);
  writeAudit({
    tx,
    path: definitionAuditPath(command.commandId),
    entityId: id,
    operation: `set-${status}`,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason,
    before: current.data,
    after: {...current.data, ...update},
  });
  return {
    resultKey: `inspection-definition-${status}`,
    aggregateVersion: nextVersion,
    result: {definitionId: id, status},
  };
};

export const createInspectionCampaign: CommandHandler = async ({tx, command, context}) => {
  exactKeys(command.payload, [
    "definitionId", "definitionVersion", "purpose", "assetTypeKey",
    "assetClassId", "targetAssetNumbers", "expectedPopulation",
    "physicalPositionLabels", "baselineCampaignId", "observerRoleKeys", "reason",
  ], "payload");
  const campaignId = documentId(command.aggregateId, "aggregateId");
  if (command.expectedVersion !== 0) {
    throw new WorkflowError("invalid-argument", "New inspection campaign expectedVersion must be zero.");
  }
  const definitionId = documentId(command.payload.definitionId, "definitionId");
  const definitionVersion = command.payload.definitionVersion;
  if (!Number.isSafeInteger(definitionVersion) || (definitionVersion as number) < 1) {
    throw new WorkflowError("invalid-argument", "definitionVersion is invalid.");
  }
  const assetTypeKey = cleanText(command.payload.assetTypeKey, "assetTypeKey");
  if (!ASSET_TYPES.has(assetTypeKey)) {
    throw new WorkflowError("invalid-argument", "assetTypeKey is unsupported.");
  }
  const assetClassId = optionalDocumentId(command.payload.assetClassId, "assetClassId");
  if (assetClassId == null) {
    throw new WorkflowError(
      "invalid-argument",
      "Inspection campaigns require one exact governed asset class.",
      {reasonCode: "inspection-campaign-asset-class-required"},
    );
  }
  const targetAssetNumbers = integerList(
    command.payload.targetAssetNumbers,
    "targetAssetNumbers",
    500,
  );
  if (targetAssetNumbers.length === 0) {
    throw new WorkflowError(
      "invalid-argument",
      "Inspection campaigns require an exact target population.",
      {reasonCode: "inspection-campaign-target-population-required"},
    );
  }
  const physicalPositionLabels = stringList(
    command.payload.physicalPositionLabels,
    "physicalPositionLabels",
    32,
    80,
  );
  const baselineCampaignId = optionalDocumentId(
    command.payload.baselineCampaignId,
    "baselineCampaignId",
  );
  const expectedPopulation = command.payload.expectedPopulation;
  if (expectedPopulation != null &&
      (!Number.isSafeInteger(expectedPopulation) || (expectedPopulation as number) < 1 ||
       (expectedPopulation as number) > 5000)) {
    throw new WorkflowError("invalid-argument", "expectedPopulation is invalid.");
  }
  const observerRoleKeys = stringList(
    command.payload.observerRoleKeys,
    "observerRoleKeys",
    20,
    48,
    false,
  );
  if (observerRoleKeys.some((role) => !OBSERVER_ROLES.has(role as RoleKey))) {
    throw new WorkflowError("invalid-argument", "observerRoleKeys contains an unsupported role.");
  }
  const reason = boundedText(command.payload.reason, "reason", 1, 500);
  const [current, definition, audit, campaignClass, campaignAssets, baseline] = await Promise.all([
    tx.get(campaignPath(campaignId)),
    tx.get(definitionPath(definitionId)),
    tx.get(campaignAuditPath(command.commandId)),
    tx.get(`asset_classes/${assetClassId}`),
    tx.query("asset_instances", [
      {field: "assetClassId", op: "==", value: assetClassId},
    ]),
    baselineCampaignId == null ? Promise.resolve(null) :
      tx.get(campaignPath(baselineCampaignId)),
  ]);
  if (current.exists || audit.exists) {
    throw new WorkflowError("already-exists", "Inspection campaign identity is already used.");
  }
  if (!definition.exists || definition.data == null || definition.data.status !== "active" ||
      definition.data.version !== definitionVersion) {
    throw new WorkflowError("failed-precondition", "Inspection definition is missing, inactive or changed.");
  }
  if (!campaignClass.exists || campaignClass.data == null ||
      campaignClass.data.status !== "active" ||
      campaignClass.data.assetClassId !== assetClassId ||
      (campaignClass.data.legacyAssetTypeKey != null &&
       campaignClass.data.legacyAssetTypeKey !== assetTypeKey)) {
    throw new WorkflowError("failed-precondition", "Campaign asset class is inactive or mismatched.");
  }
  const types = definition.data.assetTypeKeys;
  const classes = definition.data.assetClassIds;
  if ((!Array.isArray(types) || !types.includes(assetTypeKey)) &&
      (assetClassId == null || !Array.isArray(classes) || !classes.includes(assetClassId))) {
    throw new WorkflowError("failed-precondition", "Campaign asset scope does not match its definition.");
  }
  if (baseline != null && (!baseline.exists || baseline.data == null ||
      baseline.data.status !== "closed" ||
      baseline.data.definitionId !== definitionId ||
      baseline.data.assetClassId !== assetClassId)) {
    throw new WorkflowError(
      "failed-precondition",
      "A re-audit baseline must be a closed campaign for the same definition and asset class.",
      {reasonCode: "inspection-baseline-invalid"},
    );
  }
  const assetRows = campaignAssets.filter((row) => row.data != null &&
    row.data.status === "active" &&
    Number.isSafeInteger(row.data.assetNumber) &&
    targetAssetNumbers.includes(row.data.assetNumber as number));
  const byNumber = new Map<number, (typeof assetRows)[number]>();
  for (const row of assetRows) {
    const number = row.data!.assetNumber as number;
    if (byNumber.has(number)) {
      throw new WorkflowError(
        "failed-precondition",
        "The governed asset class contains duplicate active asset numbers.",
        {reasonCode: "inspection-campaign-asset-number-ambiguous", assetNumber: number},
      );
    }
    byNumber.set(number, row);
  }
  const missingAssets = targetAssetNumbers.filter((number) => !byNumber.has(number));
  if (missingAssets.length > 0) {
    throw new WorkflowError(
      "failed-precondition",
      "One or more inspection targets are absent or inactive in the governed asset registry.",
      {reasonCode: "inspection-campaign-assets-missing", missingAssetNumbers: missingAssets},
    );
  }
  const now = iso(context.serverNow);
  const componentNodeIds = Array.isArray(definition.data.componentNodeIds) ?
    definition.data.componentNodeIds.filter((item): item is string => typeof item === "string") : [];
  const targetPopulation = buildInspectionTargetPopulation({
    assetTypeKey,
    assetClassId,
    assets: targetAssetNumbers.map((number) => {
      const row = byNumber.get(number)!;
      const data = row.data!;
      if (typeof data.assetInstanceId !== "string" ||
          typeof data.name !== "string" || !Number.isSafeInteger(data.version) ||
          (data.version as number) < 1) {
        throw new WorkflowError(
          "failed-precondition",
          "An inspection target has malformed governed identity.",
          {reasonCode: "inspection-campaign-asset-identity-malformed", assetNumber: number},
        );
      }
      return {
        assetNumber: number,
        assetInstanceId: data.assetInstanceId,
        assetInstanceVersion: data.version as number,
        assetInstanceName: data.name,
      };
    }),
    componentNodeIds,
    physicalPositions: physicalPositionLabels,
    at: now,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    addedLater: false,
  });
  if (targetPopulation.length > 500 || expectedPopulation !== targetPopulation.length) {
    throw new WorkflowError(
      "invalid-argument",
      "Expected population must exactly match the governed asset, component and position targets.",
      {
        reasonCode: "inspection-campaign-population-count-mismatch",
        expectedPopulation: expectedPopulation ?? null,
        derivedPopulation: targetPopulation.length,
      },
    );
  }
  const after: JsonMap = {
    schemaVersion: 2,
    campaignId,
    version: 1,
    status: "open",
    definition: definitionSnapshot(definition.data),
    definitionId,
    definitionVersion: definitionVersion as number,
    definitionCode: definition.data.code,
    definitionTitle: definition.data.title,
    purpose: boundedText(command.payload.purpose, "purpose", 1, 1000),
    assetTypeKey,
    assetClassId,
    targetAssetNumbers,
    physicalPositionLabels,
    targetPopulation: inspectionTargetPopulationJson(targetPopulation),
    targetDispositionCounts: inspectionPopulationCounts(targetPopulation),
    expectedPopulation: targetPopulation.length,
    baselineCampaignId,
    observerRoleKeys,
    observationCount: 0,
    distinctTargetKeys: [],
    latestObservationAt: null,
    createdAt: now,
    createdByUid: context.actor.uid,
    createdByName: context.actor.name,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  };
  tx.create(campaignPath(campaignId), after);
  writeAudit({
    tx,
    path: campaignAuditPath(command.commandId),
    entityId: campaignId,
    operation: "create",
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason,
    before: {},
    after,
  });
  return {
    resultKey: "inspection-campaign-created",
    aggregateVersion: 1,
    result: {campaignId, status: "open", definitionCode: definition.data.code},
  };
};

export const setInspectionCampaignStatus: CommandHandler = async ({tx, command, context}) => {
  exactKeys(command.payload, ["status", "reason"], "payload");
  const campaignId = documentId(command.aggregateId, "aggregateId");
  const target = cleanText(command.payload.status, "status");
  if (!["open", "paused", "closed"].includes(target)) {
    throw new WorkflowError("invalid-argument", "status is unsupported.");
  }
  const reason = boundedText(command.payload.reason, "reason", 1, 500);
  const [current, audit, findings] = await Promise.all([
    tx.get(campaignPath(campaignId)),
    tx.get(campaignAuditPath(command.commandId)),
    tx.query("inspection_findings", [
      {field: "campaignId", op: "==", value: campaignId},
    ]),
  ]);
  if (!current.exists || current.data == null) {
    throw new WorkflowError("not-found", "Inspection campaign was not found.");
  }
  if (current.data.version !== command.expectedVersion) {
    throw new WorkflowError("aborted", "The inspection campaign changed before this request.");
  }
  const transitions: Readonly<Record<string, readonly string[]>> = {
    open: ["paused", "closed"],
    paused: ["open", "closed"],
    closed: [],
  };
  if (!(transitions[String(current.data.status)] ?? []).includes(target) || audit.exists) {
    throw new WorkflowError("failed-precondition", "The inspection campaign transition is invalid.");
  }
  if (target === "closed") {
    const population = parseInspectionTargetPopulation(current.data.targetPopulation);
    const counts = inspectionPopulationCounts(population);
    if (counts.pending > 0) {
      throw new WorkflowError(
        "failed-precondition",
        "Every inspection target needs evidence or an explicit disposition before closure.",
        {
          reasonCode: "inspection-campaign-population-incomplete",
          pendingTargetCount: counts.pending,
        },
      );
    }
    const blockingFindings = findings.filter((finding) => finding.data != null &&
      !["correctiveActionLinked", "verifiedResolved", "acceptedCondition", "invalidated"]
        .includes(String(finding.data.status)));
    if (blockingFindings.length > 0) {
      throw new WorkflowError(
        "failed-precondition",
        "Inspection findings require corrective linkage, verification or adjudication before closure.",
        {
          reasonCode: "inspection-campaign-findings-unaccounted",
          blockingFindingIds: blockingFindings.map((finding) =>
            finding.path.split("/").at(-1)!),
        },
      );
    }
  }
  const now = iso(context.serverNow);
  const nextVersion = command.expectedVersion + 1;
  const update: JsonMap = {
    status: target,
    version: nextVersion,
    pausedAt: target === "paused" ? now : current.data.pausedAt ?? null,
    closedAt: target === "closed" ? now : current.data.closedAt ?? null,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  };
  tx.update(campaignPath(campaignId), update);
  writeAudit({
    tx,
    path: campaignAuditPath(command.commandId),
    entityId: campaignId,
    operation: `set-${target}`,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason,
    before: current.data,
    after: {...current.data, ...update},
  });
  return {
    resultKey: `inspection-campaign-${target}`,
    aggregateVersion: nextVersion,
    result: {campaignId, status: target},
  };
};

interface ParsedObservationValue {
  readonly valueType: string;
  readonly numericValue: number | null;
  readonly booleanValue: boolean | null;
  readonly textValue: string | null;
  readonly choiceValue: string | null;
}

type InspectionComparisonOutcome =
  | "improved" | "unchanged" | "deteriorated"
  | "resolved" | "recurred" | "notComparable";

const numericDeviation = (value: number, definition: JsonMap): number => {
  const minimum = typeof definition.minimumValue === "number" ?
    definition.minimumValue : null;
  const maximum = typeof definition.maximumValue === "number" ?
    definition.maximumValue : null;
  if (minimum != null && value < minimum) return minimum - value;
  if (maximum != null && value > maximum) return value - maximum;
  return 0;
};

const compareInspectionObservation = (
  current: ParsedObservationValue,
  baseline: JsonMap,
  definition: JsonMap,
): InspectionComparisonOutcome => {
  if (current.valueType === "number" && current.numericValue != null &&
      typeof baseline.numericValue === "number") {
    const previous = numericDeviation(baseline.numericValue, definition);
    const next = numericDeviation(current.numericValue, definition);
    if (previous > 0 && next === 0) return "resolved";
    if (previous === 0 && next > 0) return "recurred";
    if (next < previous) return "improved";
    if (next > previous) return "deteriorated";
    return "unchanged";
  }
  const key = current.valueType === "boolean" ? "booleanValue" :
    current.valueType === "text" ? "textValue" :
      current.valueType === "choice" ? "choiceValue" : null;
  if (key == null || baseline[key] == null) return "notComparable";
  const next = current.valueType === "boolean" ? current.booleanValue :
    current.valueType === "text" ? current.textValue : current.choiceValue;
  return baseline[key] === next ? "unchanged" : "notComparable";
};

const parseObservationValue = (
  value: unknown,
  definition: JsonMap,
): ParsedObservationValue => {
  const data = record(value, "observation.value");
  exactKeys(data, [
    "valueType", "numericValue", "booleanValue", "textValue", "choiceValue",
  ], "observation.value");
  const expected = cleanText(definition.valueType, "definition.valueType");
  if (data.valueType !== expected) {
    throw new WorkflowError("invalid-argument", "Observation value type changed from its definition.");
  }
  const result: ParsedObservationValue = {
    valueType: expected,
    numericValue: null,
    booleanValue: null,
    textValue: null,
    choiceValue: null,
  };
  if (expected === "number") {
    if (typeof data.numericValue !== "number" || !Number.isFinite(data.numericValue) ||
        data.booleanValue != null || data.textValue != null || data.choiceValue != null) {
      throw new WorkflowError("invalid-argument", "Numeric observation value is invalid.");
    }
    return {...result, numericValue: data.numericValue};
  }
  if (expected === "boolean") {
    if (typeof data.booleanValue !== "boolean" || data.numericValue != null ||
        data.textValue != null || data.choiceValue != null) {
      throw new WorkflowError("invalid-argument", "Boolean observation value is invalid.");
    }
    return {...result, booleanValue: data.booleanValue};
  }
  if (expected === "text") {
    if (data.numericValue != null || data.booleanValue != null || data.choiceValue != null) {
      throw new WorkflowError("invalid-argument", "Text observation value is invalid.");
    }
    return {...result, textValue: boundedText(data.textValue, "textValue", 1, 1000)};
  }
  const choice = boundedText(data.choiceValue, "choiceValue", 1, 120);
  if (data.numericValue != null || data.booleanValue != null || data.textValue != null ||
      !Array.isArray(definition.choiceValues) || !definition.choiceValues.includes(choice)) {
    throw new WorkflowError("invalid-argument", "Choice observation value is invalid.");
  }
  return {...result, choiceValue: choice};
};

const operatingConditions = (value: unknown): JsonMap => {
  const data = record(value, "operatingConditions");
  const keys = Object.keys(data);
  if (keys.length > 30 || keys.some((key) => key.trim().length === 0 || key.length > 80 ||
      typeof data[key] !== "string" || (data[key] as string).trim().length > 240)) {
    throw new WorkflowError("invalid-argument", "operatingConditions is invalid.");
  }
  return Object.fromEntries(keys.sort().map((key) => [key.trim(), (data[key] as string).trim()]));
};

export const recordInspectionObservation: CommandHandler = async ({tx, command, context}) => {
  exactKeys(command.payload, [
    "observationId", "definitionVersion", "assetTypeKey", "assetNumber",
    "assetClassId", "assetInstanceId", "componentNodeId", "componentNodeVersion",
    "componentName", "hierarchyPath", "physicalPosition", "observedAt", "value",
    "unit", "operatingConditions", "chargeNo", "note", "evidenceUrls",
    "supersedesObservationId",
  ], "payload");
  const campaignId = documentId(command.aggregateId, "aggregateId");
  const observationId = documentId(command.payload.observationId, "observationId");
  const [campaign, existingObservation, superseded] = await Promise.all([
    tx.get(campaignPath(campaignId)),
    tx.get(observationPath(observationId)),
    command.payload.supersedesObservationId == null ? Promise.resolve(null) :
      tx.get(observationPath(documentId(
        command.payload.supersedesObservationId,
        "supersedesObservationId",
      ))),
  ]);
  if (!campaign.exists || campaign.data == null) {
    throw new WorkflowError("not-found", "Inspection campaign was not found.");
  }
  if (campaign.data.version !== command.expectedVersion) {
    throw new WorkflowError("aborted", "The inspection campaign changed before this reading.");
  }
  if (campaign.data.status !== "open") {
    throw new WorkflowError("failed-precondition", "Only an open campaign accepts observations.");
  }
  if (existingObservation.exists) {
    throw new WorkflowError("already-exists", "Observation identity is already used.");
  }
  const observerRoles = campaign.data.observerRoleKeys;
  const isGovernanceObserver = context.actor.roles.has("admin") ||
    context.actor.roles.has("si");
  if (!Array.isArray(observerRoles) ||
      (![...context.actor.roles].some((role) => observerRoles.includes(role)) &&
       !isGovernanceObserver)) {
    throw new WorkflowError("permission-denied", "Actor is not an observer for this campaign.");
  }
  if (campaign.data.definitionVersion !== command.payload.definitionVersion) {
    throw new WorkflowError("aborted", "The frozen inspection definition version does not match.");
  }
  const definition = record(campaign.data.definition, "campaign.definition");
  const assetTypeKey = cleanText(command.payload.assetTypeKey, "assetTypeKey");
  const assetNumber = command.payload.assetNumber;
  if (assetTypeKey !== campaign.data.assetTypeKey || !Number.isSafeInteger(assetNumber) ||
      (assetNumber as number) < 1) {
    throw new WorkflowError("invalid-argument", "Observation asset is outside the campaign scope.");
  }
  const targetAssetNumbers = campaign.data.targetAssetNumbers;
  if (Array.isArray(targetAssetNumbers) && targetAssetNumbers.length > 0 &&
      !targetAssetNumbers.includes(assetNumber)) {
    throw new WorkflowError("failed-precondition", "Observation asset is not in the target list.");
  }
  const assetClassId = optionalDocumentId(command.payload.assetClassId, "assetClassId");
  const assetInstanceId = optionalDocumentId(command.payload.assetInstanceId, "assetInstanceId");
  if (assetClassId == null || assetInstanceId == null ||
      assetClassId !== campaign.data.assetClassId) {
    throw new WorkflowError("invalid-argument", "Observation registry identity is invalid.");
  }
  const componentNodeId = optionalDocumentId(command.payload.componentNodeId, "componentNodeId");
  const componentNodeVersion = command.payload.componentNodeVersion;
  const componentName = optionalText(command.payload.componentName, "componentName", 160);
  const hierarchyPath = stringList(command.payload.hierarchyPath, "hierarchyPath", 20, 160);
  if ((componentNodeId == null) !== (componentNodeVersion == null) ||
      (componentNodeId == null) !== (componentName == null) ||
      (componentNodeVersion != null &&
       (!Number.isSafeInteger(componentNodeVersion) || (componentNodeVersion as number) < 1))) {
    throw new WorkflowError("invalid-argument", "Observation component identity is incomplete.");
  }
  const definedComponents = definition.componentNodeIds;
  if (Array.isArray(definedComponents) && definedComponents.length > 0 &&
      (componentNodeId == null || !definedComponents.includes(componentNodeId))) {
    throw new WorkflowError("failed-precondition", "Observation component is outside the definition.");
  }
  const physicalPosition = optionalText(
    command.payload.physicalPosition,
    "physicalPosition",
    80,
  );
  const targetKey = inspectionTargetKey({
    assetClassId,
    assetInstanceId,
    componentNodeId,
    physicalPosition,
  });
  const targetPopulation = parseInspectionTargetPopulation(
    campaign.data.targetPopulation,
  );
  const governedTarget = targetPopulation.find((target) =>
    target.targetKey === targetKey);
  if (governedTarget == null || governedTarget.assetNumber !== assetNumber ||
      governedTarget.assetTypeKey !== assetTypeKey) {
    throw new WorkflowError(
      "failed-precondition",
      "Observation target is not part of the governed campaign population.",
      {reasonCode: "inspection-target-not-in-population", targetKey},
    );
  }
  const value = parseObservationValue(command.payload.value, definition);
  const unit = optionalText(command.payload.unit, "unit", 40);
  if (unit !== (definition.unit ?? null)) {
    throw new WorkflowError("invalid-argument", "Observation unit changed from its definition.");
  }
  const chargeNo = command.payload.chargeNo;
  if (chargeNo != null && !isFiveDigitChargeNumber(chargeNo)) {
    throw new WorkflowError("invalid-argument", "chargeNo must be an exact five-digit number.");
  }
  if (definition.requiresChargeNo === true && chargeNo == null) {
    throw new WorkflowError("invalid-argument", "This inspection requires a charge number.");
  }
  if (superseded != null) {
    if (!superseded.exists || superseded.data == null ||
        superseded.data.campaignId !== campaignId) {
      throw new WorkflowError("failed-precondition", "Superseded observation is missing or unrelated.");
    }
    const canCorrect = superseded.data.observerUid === context.actor.uid ||
      ["admin", "si", "contractSupervisor", "shiftSupervisor"]
        .some((role) => context.actor.roles.has(role as RoleKey));
    if (!canCorrect) {
      throw new WorkflowError("permission-denied", "Actor cannot correct this observation.");
    }
  }
  const instance = assetInstanceId == null ? null : await tx.get(`asset_instances/${assetInstanceId}`);
  const node = componentNodeId == null ? null : await tx.get(`asset_hierarchy_nodes/${componentNodeId}`);
  if (instance != null && (!instance.exists || instance.data == null ||
      instance.data.status !== "active" || instance.data.assetNumber !== assetNumber ||
      instance.data.assetClassId !== assetClassId)) {
    throw new WorkflowError("failed-precondition", "Observation asset identity is stale.");
  }
  if (node != null && (!node.exists || node.data == null || node.data.status !== "active" ||
      node.data.version !== componentNodeVersion || node.data.name !== componentName ||
      (assetClassId != null && node.data.assetClassId !== assetClassId))) {
    throw new WorkflowError("failed-precondition", "Observation component identity is stale.");
  }
  const observedAt = isoDate(command.payload.observedAt, "observedAt");
  if (new Date(observedAt).getTime() > context.serverNow.getTime() + 5 * 60 * 1000) {
    throw new WorkflowError("invalid-argument", "observedAt cannot be in the future.");
  }
  const numeric = value.numericValue;
  const minimum = typeof definition.minimumValue === "number" ? definition.minimumValue : null;
  const maximum = typeof definition.maximumValue === "number" ? definition.maximumValue : null;
  const outOfRange = numeric != null &&
    ((minimum != null && numeric < minimum) || (maximum != null && numeric > maximum));
  if (superseded?.data != null &&
      (superseded.data.targetKey !== targetKey ||
       superseded.data.definitionVersion !== campaign.data.definitionVersion)) {
    throw new WorkflowError(
      "failed-precondition",
      "A correction must retain the original inspected target and definition.",
    );
  }
  const distinct = Array.isArray(campaign.data.distinctTargetKeys) ?
    campaign.data.distinctTargetKeys.filter((item): item is string => typeof item === "string") : [];
  if (!distinct.includes(targetKey)) {
    if (distinct.length >= 1000) {
      throw new WorkflowError(
        "failed-precondition",
        "Campaign distinct-target projection reached its governed limit.",
        {reasonCode: "inspection-distinct-target-limit-reached"},
      );
    }
    distinct.push(targetKey);
  }
  const now = iso(context.serverNow);
  const nextVersion = command.expectedVersion + 1;
  const baselineCampaignId = typeof campaign.data.baselineCampaignId === "string" ?
    campaign.data.baselineCampaignId : null;
  const [baselineRows, findingRows] = await Promise.all([
    baselineCampaignId == null ? Promise.resolve([]) :
      tx.query("inspection_observations", [
        {field: "campaignId", op: "==", value: baselineCampaignId},
        {field: "targetKey", op: "==", value: targetKey},
      ]),
    tx.query("inspection_findings", [
      {field: "campaignId", op: "==", value: campaignId},
      {field: "targetKey", op: "==", value: targetKey},
    ]),
  ]);
  const baselineSupersededIds = new Set(baselineRows
    .map((row) => row.data?.supersedesObservationId)
    .filter((item): item is string => typeof item === "string"));
  const baselineObservation = baselineRows
    .filter((row) => row.data != null && !baselineSupersededIds.has(
      String(row.data.observationId ?? ""),
    ))
    .sort((left, right) => String(right.data?.observedAt ?? "")
      .localeCompare(String(left.data?.observedAt ?? "")))[0]?.data ?? null;
  const comparisonOutcome = baselineObservation == null ? null :
    compareInspectionObservation(value, baselineObservation, definition);
  const activeFindings = findingRows.filter((row) => row.data != null &&
    !["verifiedResolved", "acceptedCondition", "invalidated"]
      .includes(String(row.data.status)));
  if (activeFindings.length > 1) {
    throw new WorkflowError(
      "failed-precondition",
      "Inspection target has multiple active findings and requires adjudication.",
      {reasonCode: "inspection-finding-population-conflict", targetKey},
    );
  }
  const observation: JsonMap = {
    schemaVersion: 1,
    observationId,
    campaignId,
    campaignVersionAtObservation: command.expectedVersion,
    definition: definition,
    definitionId: campaign.data.definitionId,
    definitionVersion: campaign.data.definitionVersion,
    definitionCode: campaign.data.definitionCode,
    assetTypeKey,
    assetNumber: assetNumber as number,
    assetClassId,
    assetInstanceId,
    componentNodeId,
    componentNodeVersion: componentNodeVersion as number | null,
    componentName,
    hierarchyPath,
    physicalPosition,
    targetKey,
    observedAt,
    observerUid: context.actor.uid,
    observerName: context.actor.name,
    value: value as unknown as JsonMap,
    valueType: value.valueType,
    numericValue: value.numericValue,
    booleanValue: value.booleanValue,
    textValue: value.textValue,
    choiceValue: value.choiceValue,
    unit,
    minimumValue: minimum,
    maximumValue: maximum,
    outOfRange,
    operatingConditions: operatingConditions(command.payload.operatingConditions),
    chargeNo: chargeNo as number | null,
    note: optionalText(command.payload.note, "note", 2000),
    evidenceUrls: stringList(command.payload.evidenceUrls, "evidenceUrls", 20, 1000),
    supersedesObservationId: superseded?.data == null ? null :
      documentId(command.payload.supersedesObservationId, "supersedesObservationId"),
    baselineCampaignId,
    baselineObservationId: baselineObservation?.observationId ?? null,
    comparisonOutcome,
    recordedAt: now,
  };
  tx.create(observationPath(observationId), observation);
  const observedPopulation = markInspectionTargetObserved({
    targets: targetPopulation,
    targetKey,
    observationId,
    observedAt,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
  });
  let findingId: string | null = null;
  const activeFinding = activeFindings[0] ?? null;
  if (outOfRange || activeFinding != null) {
    findingId = typeof activeFinding?.data?.findingId === "string" ?
      activeFinding.data.findingId : `inspection-finding-${observationId}`;
    const previous = activeFinding?.data ?? null;
    const findingVersion = previous == null ? 1 : Number(previous.version ?? 0) + 1;
    const finding: JsonMap = {
      schemaVersion: 1,
      findingId,
      version: findingVersion,
      campaignId,
      definitionId: campaign.data.definitionId,
      definitionVersion: campaign.data.definitionVersion,
      targetKey,
      assetTypeKey,
      assetNumber: assetNumber as number,
      assetClassId,
      assetInstanceId,
      componentNodeId,
      componentName,
      physicalPosition,
      status: outOfRange ? "open" : "awaitingVerification",
      firstObservationId: previous?.firstObservationId ?? observationId,
      currentObservationId: observationId,
      firstObservedAt: previous?.firstObservedAt ?? observedAt,
      latestObservedAt: observedAt,
      recurrenceCount: Number(previous?.recurrenceCount ?? 0) + (outOfRange ? 1 : 0),
      linkedTicketId: previous?.linkedTicketId ?? null,
      verificationCount: Number(previous?.verificationCount ?? 0),
      createdAt: previous?.createdAt ?? now,
      createdByUid: previous?.createdByUid ?? context.actor.uid,
      createdByName: previous?.createdByName ?? context.actor.name,
      updatedAt: now,
      updatedByUid: context.actor.uid,
      updatedByName: context.actor.name,
    };
    if (activeFinding == null) tx.create(`inspection_findings/${findingId}`, finding);
    else tx.update(activeFinding.path, finding);
    tx.create(`inspection_finding_events/${command.commandId}`, {
      schemaVersion: 1,
      eventId: command.commandId,
      findingId,
      campaignId,
      operation: previous == null ? "create" : "record-follow-up-observation",
      previousStatus: previous?.status ?? null,
      resultingStatus: finding.status,
      observationId,
      performedAt: now,
      performedByUid: context.actor.uid,
      performedByName: context.actor.name,
    });
  }
  const priorLatest = persistedInstantText(campaign.data.latestObservationAt);
  tx.update(campaignPath(campaignId), {
    version: nextVersion,
    observationCount: Number(campaign.data.observationCount ?? 0) + 1,
    distinctTargetKeys: distinct,
    targetPopulation: inspectionTargetPopulationJson(observedPopulation),
    targetDispositionCounts: inspectionPopulationCounts(observedPopulation),
    latestObservationAt: priorLatest == null || observedAt > priorLatest ?
      observedAt : priorLatest,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  });
  return {
    resultKey: superseded == null ? "inspection-observation-recorded" :
      "inspection-observation-correction-recorded",
    aggregateVersion: nextVersion,
    result: {
      campaignId,
      observationId,
      targetKey,
      outOfRange,
      issueRecommended: outOfRange,
      findingId,
      comparisonOutcome,
      observationCount: Number(campaign.data.observationCount ?? 0) + 1,
      distinctTargetCount: distinct.length,
    },
  };
};

export const linkInspectionObservationIssue: CommandHandler = async ({tx, command, context}) => {
  exactKeys(command.payload, ["observationId", "ticketId", "reason"], "payload");
  const campaignId = documentId(command.aggregateId, "aggregateId");
  const observationId = documentId(command.payload.observationId, "observationId");
  const ticketId = documentId(command.payload.ticketId, "ticketId");
  const reason = boundedText(command.payload.reason, "reason", 1, 500);
  const linkId = `${observationId}_${ticketId}`;
  const [campaign, observation, ticket, link] = await Promise.all([
    tx.get(campaignPath(campaignId)),
    tx.get(observationPath(observationId)),
    tx.get(`maintenance_records/${ticketId}`),
    tx.get(issueLinkPath(linkId)),
  ]);
  if (!campaign.exists || campaign.data == null || campaign.data.version !== command.expectedVersion) {
    throw new WorkflowError("aborted", "Inspection campaign is missing or changed.");
  }
  const observerRoles = campaign.data.observerRoleKeys;
  const canLink = context.actor.roles.has("admin") || context.actor.roles.has("si") ||
    context.actor.roles.has("contractSupervisor") ||
    context.actor.roles.has("shiftSupervisor") ||
    (Array.isArray(observerRoles) &&
     [...context.actor.roles].some((role) => observerRoles.includes(role)));
  if (!canLink) {
    throw new WorkflowError("permission-denied", "Actor cannot link issues to this campaign.");
  }
  if (!observation.exists || observation.data == null || observation.data.campaignId !== campaignId) {
    throw new WorkflowError("not-found", "Inspection observation was not found in this campaign.");
  }
  if (!ticket.exists || ticket.data == null || ticket.data.isDeleted === true) {
    throw new WorkflowError("not-found", "Maintenance issue was not found.");
  }
  if (ticket.data.assetType !== observation.data.assetTypeKey ||
      ticket.data.assetNumber !== observation.data.assetNumber) {
    throw new WorkflowError("failed-precondition", "Maintenance issue targets a different asset.");
  }
  if (link.exists) {
    throw new WorkflowError("already-exists", "This observation and issue are already linked.");
  }
  const findingRows = await tx.query("inspection_findings", [
    {field: "campaignId", op: "==", value: campaignId},
    {field: "targetKey", op: "==", value: observation.data.targetKey},
  ]);
  const activeFindings = findingRows.filter((row) => row.data != null &&
    !["verifiedResolved", "acceptedCondition", "invalidated"]
      .includes(String(row.data.status)));
  if (activeFindings.length > 1) {
    throw new WorkflowError(
      "failed-precondition",
      "Inspection target has multiple active findings and requires adjudication.",
      {reasonCode: "inspection-finding-population-conflict"},
    );
  }
  const finding = activeFindings[0] ?? null;
  if (finding?.data != null && typeof finding.data.linkedTicketId === "string" &&
      finding.data.linkedTicketId !== ticketId) {
    throw new WorkflowError(
      "failed-precondition",
      "This finding is already bound to another corrective maintenance issue.",
      {reasonCode: "inspection-finding-corrective-action-already-linked"},
    );
  }
  const now = iso(context.serverNow);
  tx.create(issueLinkPath(linkId), {
    schemaVersion: 1,
    linkId,
    campaignId,
    observationId,
    ticketId,
    assetTypeKey: observation.data.assetTypeKey,
    assetNumber: observation.data.assetNumber,
    outOfRange: observation.data.outOfRange === true,
    linkedByUid: context.actor.uid,
    linkedByName: context.actor.name,
    linkedAt: now,
    reason,
  });
  if (finding?.data != null) {
    const findingId = documentId(finding.data.findingId, "findingId");
    tx.update(finding.path, {
      version: Number(finding.data.version ?? 0) + 1,
      status: "correctiveActionLinked",
      linkedTicketId: ticketId,
      linkedAt: now,
      linkedByUid: context.actor.uid,
      linkedByName: context.actor.name,
      updatedAt: now,
      updatedByUid: context.actor.uid,
      updatedByName: context.actor.name,
    });
    tx.create(`inspection_finding_events/${command.commandId}`, {
      schemaVersion: 1,
      eventId: command.commandId,
      findingId,
      campaignId,
      operation: "link-corrective-action",
      previousStatus: finding.data.status,
      resultingStatus: "correctiveActionLinked",
      observationId,
      ticketId,
      reason,
      performedAt: now,
      performedByUid: context.actor.uid,
      performedByName: context.actor.name,
    });
  }
  return {
    resultKey: "inspection-observation-issue-linked",
    aggregateVersion: command.expectedVersion,
    result: {campaignId, observationId, ticketId, linkId},
  };
};
