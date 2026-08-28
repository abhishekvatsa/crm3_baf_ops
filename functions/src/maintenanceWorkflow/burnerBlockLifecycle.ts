import {createHash} from "crypto";

import {
  PersistedActionPayloadError,
  readComponentActionPayload,
} from "../persistedActionPayload";
import {
  PersistedWorkPayloadError,
  readFieldResponsePayload,
} from "../persistedWorkPayload";
import {WorkflowError} from "./errors";
import {WorkflowTransaction} from "./store";
import {Actor, JsonMap} from "./types";

type ActionRow = Record<string, unknown>;

export type BurnerLifecycleSourceType =
  | "maintenanceIssue"
  | "legacyPlannedJob"
  | "workflowPlannedJob";

export interface BurnerLifecycleActionSource {
  readonly sourceModuleId: string | null;
  readonly discipline?: unknown;
  readonly actionsJson: unknown;
  readonly responsesJson?: unknown;
}

export interface BurnerBlockLifecycleWritePlan {
  readonly events: readonly {
    readonly path: string;
    readonly data: JsonMap;
  }[];
  readonly currentStates: readonly {
    readonly path: string;
    readonly data: JsonMap;
  }[];
}

interface BurnerBlockChangeDecision {
  readonly state: "changed" | "unchanged";
  readonly burnerPosition: number | null;
}

const requiredText = (value: unknown, field: string): string => {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new WorkflowError(
      "failed-precondition",
      `Burner-block lifecycle ${field} is missing.`,
      {reasonCode: "burner-block-lifecycle-invalid", field},
    );
  }
  return value.trim();
};

const positiveInteger = (value: unknown, field: string): number => {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 1) {
    throw new WorkflowError(
      "failed-precondition",
      `Burner-block lifecycle ${field} is invalid.`,
      {reasonCode: "burner-block-lifecycle-invalid", field},
    );
  }
  return value;
};

const optionalText = (value: unknown, field: string): string | null => {
  if (value == null) return null;
  const parsed = requiredText(value, field);
  if (parsed.length > 160) {
    throw new WorkflowError(
      "failed-precondition",
      `Burner-block lifecycle ${field} is too long.`,
      {reasonCode: "burner-block-lifecycle-invalid", field},
    );
  }
  return parsed;
};

const record = (value: unknown, field: string): ActionRow => {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new WorkflowError(
      "failed-precondition",
      `Burner-block lifecycle ${field} is invalid.`,
      {reasonCode: "burner-block-lifecycle-invalid", field},
    );
  }
  return value as ActionRow;
};

const stringList = (value: unknown, field: string): string[] => {
  if (!Array.isArray(value) || value.length === 0 || value.length > 20 ||
      value.some((item) => typeof item !== "string" || item.trim().length === 0)) {
    throw new WorkflowError(
      "failed-precondition",
      `Burner-block lifecycle ${field} is invalid.`,
      {reasonCode: "burner-block-lifecycle-invalid", field},
    );
  }
  return value.map((item) => (item as string).trim());
};

const normalizedTag = (value: string): string =>
  value.trim().toUpperCase().replace(/[^A-Z0-9]+/g, "");

const isBurnerBlockIdentity = (...values: unknown[]): boolean => {
  const identity = values.flatMap((value) =>
    Array.isArray(value) ? value : [value])
    .map((value) => String(value ?? ""))
    .join(" ")
    .toLowerCase();
  return identity.includes("burner block") || identity.includes("firing tube");
};

const isBurnerBlockReplacement = (row: ActionRow): boolean =>
  (row.actionType ?? row.action) === "replacement" &&
  isBurnerBlockIdentity(
    row.component,
    (row.assetHierarchyRef as ActionRow | null)?.nodeName,
    (row.assetHierarchyRef as ActionRow | null)?.hierarchyPath,
  );

const normalizedKey = (value: unknown): string =>
  typeof value === "string" ?
    value.trim().toLowerCase().replace(/[^a-z0-9]+/g, "") : "";

const responseKey = (row: ActionRow): string => {
  for (const alias of ["key", "fieldId", "fieldKey", "id", "name"] as const) {
    const candidate = row[alias];
    if (typeof candidate === "string" && candidate.trim().length > 0) {
      return candidate.trim();
    }
  }
  throw new WorkflowError(
    "failed-precondition",
    "Saved burner-block response key is invalid.",
    {reasonCode: "burner-block-lifecycle-responses-invalid"},
  );
};

const declaresBurnerBlockChange = (value: unknown): boolean => {
  if (value === true) return true;
  if (typeof value !== "string") return false;
  return ["true", "yes", "changed", "replaced", "done"].includes(
    normalizedKey(value),
  );
};

const burnerBlockChangeDecision = (
  value: unknown,
): "changed" | "unchanged" | null => {
  if (declaresBurnerBlockChange(value)) return "changed";
  if (value === false) return "unchanged";
  if (typeof value !== "string") return null;
  return ["false", "no", "unchanged", "notchanged", "none"].includes(
    normalizedKey(value),
  ) ? "unchanged" : null;
};

const burnerPositionFromResponse = (value: unknown): number | null => {
  if (typeof value === "number" && Number.isSafeInteger(value) &&
      value >= 1 && value <= 8) {
    return value;
  }
  if (typeof value !== "string") return null;
  const match = /^(?:burner)?([1-8])$/.exec(normalizedKey(value));
  return match == null ? null : Number(match[1]);
};

const moduleBurnerBlockChangeDecision = (
  source: BurnerLifecycleActionSource,
): BurnerBlockChangeDecision | null => {
  if (source.responsesJson == null) return null;
  let payload;
  try {
    payload = readFieldResponsePayload(source.responsesJson, {
      field: `module ${source.sourceModuleId ?? "unknown"} responsesJson`,
    });
  } catch (error) {
    if (error instanceof PersistedWorkPayloadError) {
      throw new WorkflowError(
        "failed-precondition",
        "Saved module response evidence needs repair before closure.",
        {
          reasonCode: "burner-block-lifecycle-responses-invalid",
          field: error.field,
        },
      );
    }
    throw error;
  }
  let decision: "changed" | "unchanged" | null = null;
  const burnerTargetValues: unknown[] = [];
  for (const row of payload.rows) {
    const key = responseKey(row);
    const value = Object.prototype.hasOwnProperty.call(row, "value") ?
      row.value : row.answer;
    if (normalizedKey(key) === "burnertarget") {
      burnerTargetValues.push(value);
      continue;
    }
    if (normalizedKey(key) !== "burnerblockchanged") continue;
    const rowDecision = burnerBlockChangeDecision(value);
    if (rowDecision == null) continue;
    if (decision != null && decision !== rowDecision) {
      throw new WorkflowError(
        "failed-precondition",
        "Saved burner-block change responses contradict each other.",
        {reasonCode: "burner-block-lifecycle-response-conflict"},
      );
    }
    decision = rowDecision;
  }
  if (decision == null) return null;

  let burnerPosition: number | null = null;
  for (const value of burnerTargetValues) {
    const rowPosition = burnerPositionFromResponse(value);
    if (rowPosition == null) {
      throw new WorkflowError(
        "failed-precondition",
        "Saved burner-block target must identify Burner 1 through Burner 8.",
        {reasonCode: "burner-block-lifecycle-response-target-invalid"},
      );
    }
    if (burnerPosition != null && rowPosition !== burnerPosition) {
      throw new WorkflowError(
        "failed-precondition",
        "Saved burner-block target responses contradict each other.",
        {reasonCode: "burner-block-lifecycle-response-conflict"},
      );
    }
    burnerPosition = rowPosition;
  }
  return {
    state: decision,
    burnerPosition,
  };
};

const parseInstant = (value: unknown, field: string): string => {
  const text = requiredText(value, field);
  const parsed = new Date(text);
  if (!Number.isFinite(parsed.getTime())) {
    throw new WorkflowError(
      "failed-precondition",
      `Burner-block lifecycle ${field} is invalid.`,
      {reasonCode: "burner-block-lifecycle-invalid", field},
    );
  }
  return parsed.toISOString();
};

const validateTarget = async (args: {
  tx: WorkflowTransaction;
  row: ActionRow;
  expectedAssetNumber: number;
}): Promise<{
  readonly assetClassId: string;
  readonly assetClassCode: string;
  readonly assetClassName: string;
  readonly assetInstanceId: string;
  readonly assetInstanceName: string;
  readonly nodeId: string;
  readonly nodeName: string;
  readonly hierarchyPath: readonly string[];
  readonly componentTag: string | null;
}> => {
  const reference = record(args.row.assetHierarchyRef, "assetHierarchyRef");
  const scope = requiredText(reference.scope, "assetHierarchyRef.scope");
  if (!["componentDefinitionOnAsset", "installedComponent"].includes(scope)) {
    throw new WorkflowError(
      "failed-precondition",
      "Burner-block replacement must target a governed component on the Furnace.",
      {reasonCode: "burner-block-lifecycle-target-invalid"},
    );
  }
  const supportedReferenceSchemas = scope === "componentDefinitionOnAsset" ?
    [4] : [2, 3];
  if (!supportedReferenceSchemas.includes(reference.schemaVersion as number)) {
    throw new WorkflowError(
      "failed-precondition",
      "Burner-block replacement uses an unsupported hierarchy reference.",
      {reasonCode: "burner-block-lifecycle-target-invalid"},
    );
  }
  const classId = requiredText(
    reference.assetClassId,
    "assetHierarchyRef.assetClassId",
  );
  const assetId = requiredText(
    reference.assetInstanceId,
    "assetHierarchyRef.assetInstanceId",
  );
  const nodeId = requiredText(reference.nodeId, "assetHierarchyRef.nodeId");
  const assetVersion = positiveInteger(
    reference.assetInstanceVersion,
    "assetHierarchyRef.assetInstanceVersion",
  );
  const nodeVersion = positiveInteger(
    reference.nodeVersion,
    "assetHierarchyRef.nodeVersion",
  );
  const [classSnapshot, assetSnapshot, nodeSnapshot] = await Promise.all([
    args.tx.get(`asset_classes/${classId}`),
    args.tx.get(`asset_instances/${assetId}`),
    args.tx.get(`asset_hierarchy_nodes/${nodeId}`),
  ]);
  const assetClass = classSnapshot.data;
  const asset = assetSnapshot.data;
  const node = nodeSnapshot.data;
  if (!classSnapshot.exists || assetClass == null ||
      assetClass.schemaVersion !== 1 || assetClass.assetClassId !== classId ||
      assetClass.status !== "active" ||
      assetClass.legacyAssetTypeKey !== "furnace" ||
      !assetSnapshot.exists || asset == null || asset.schemaVersion !== 1 ||
      asset.assetInstanceId !== assetId || asset.assetClassId !== classId ||
      asset.status !== "active" || asset.assetNumber !== args.expectedAssetNumber ||
      asset.assetClassCode !== assetClass.code ||
      asset.assetClassName !== assetClass.name ||
      !nodeSnapshot.exists || node == null || node.schemaVersion !== 1 ||
      node.nodeId !== nodeId || node.assetClassId !== classId ||
      node.status !== "active" || node.version !== nodeVersion ||
      !["component", "subcomponent"].includes(String(node.nodeType)) ||
      !isBurnerBlockIdentity(node.name, node.hierarchyPath)) {
    throw new WorkflowError(
      "aborted",
      "The governed Furnace burner-block target changed before closure.",
      {reasonCode: "burner-block-lifecycle-target-changed"},
    );
  }

  let componentTag = optionalText(node.componentTag, "componentTag");
  if (scope === "installedComponent") {
    const componentId = requiredText(
      reference.componentInstanceId,
      "assetHierarchyRef.componentInstanceId",
    );
    const componentVersion = positiveInteger(
      reference.componentInstanceVersion,
      "assetHierarchyRef.componentInstanceVersion",
    );
    const componentSnapshot = await args.tx.get(
      `asset_component_instances/${componentId}`,
    );
    const component = componentSnapshot.data;
    componentTag = optionalText(component?.componentTag, "componentTag");
    const actionTag = optionalText(args.row.tag, "action.tag");
    if (!componentSnapshot.exists || component == null ||
        component.schemaVersion !== 1 ||
        component.componentInstanceId !== componentId ||
        component.assetClassId !== classId ||
        component.assetInstanceId !== assetId ||
        component.assetNumber !== args.expectedAssetNumber ||
        component.status !== "active" ||
        component.version !== componentVersion ||
        component.assetInstanceVersionAtMutation !== assetVersion ||
        component.definitionNodeId !== nodeId ||
        component.definitionNodeVersion !== nodeVersion ||
        componentTag == null || actionTag == null ||
        normalizedTag(componentTag) !== normalizedTag(actionTag)) {
      throw new WorkflowError(
        "aborted",
        "The installed burner-block tag changed before closure.",
        {reasonCode: "burner-block-lifecycle-tag-changed"},
      );
    }
  } else {
    const actionTag = optionalText(args.row.tag, "action.tag");
    if (asset.version !== assetVersion ||
        (actionTag != null &&
          (componentTag == null ||
            normalizedTag(actionTag) !== normalizedTag(componentTag)))) {
      throw new WorkflowError(
        "aborted",
        "The Furnace hierarchy target changed before closure.",
        {reasonCode: "burner-block-lifecycle-target-changed"},
      );
    }
  }

  const hierarchyPath = stringList(node.hierarchyPath, "hierarchyPath");
  if (requiredText(args.row.component, "action.component") !== node.name ||
      !isBurnerBlockIdentity(args.row.component, hierarchyPath)) {
    throw new WorkflowError(
      "failed-precondition",
      "The component action does not match the governed burner-block target.",
      {reasonCode: "burner-block-lifecycle-target-mismatch"},
    );
  }
  return {
    assetClassId: classId,
    assetClassCode: requiredText(assetClass.code, "assetClass.code"),
    assetClassName: requiredText(assetClass.name, "assetClass.name"),
    assetInstanceId: assetId,
    assetInstanceName: requiredText(asset.name, "asset.name"),
    nodeId,
    nodeName: requiredText(node.name, "node.name"),
    hierarchyPath,
    componentTag,
  };
};

const eventId = (parts: readonly string[]): string =>
  `bbl_${createHash("sha256").update(parts.join("|"), "utf8")
    .digest("hex").slice(0, 40)}`;

const currentStateId = (assetInstanceId: string, burnerPosition: number): string =>
  `bblc_${createHash("sha256")
    .update(`${assetInstanceId}|${burnerPosition}`, "utf8")
    .digest("hex").slice(0, 40)}`;

const isLaterLifecycleData = (candidate: JsonMap, current: JsonMap): boolean => {
  const candidatePerformedAt = Date.parse(parseInstant(
    candidate.actionPerformedAt,
    "current.actionPerformedAt",
  ));
  const currentPerformedAt = Date.parse(parseInstant(
    current.actionPerformedAt,
    "current.actionPerformedAt",
  ));
  if (candidatePerformedAt !== currentPerformedAt) {
    return candidatePerformedAt > currentPerformedAt;
  }
  const candidateCompletedAt = Date.parse(parseInstant(
    candidate.completedAt,
    "current.completedAt",
  ));
  const currentCompletedAt = Date.parse(parseInstant(
    current.completedAt,
    "current.completedAt",
  ));
  if (candidateCompletedAt !== currentCompletedAt) {
    return candidateCompletedAt > currentCompletedAt;
  }
  return requiredText(candidate.eventId, "current.eventId") >
    requiredText(current.eventId, "current.eventId");
};

export const prepareBurnerBlockLifecycleWritePlan = async (args: {
  readonly tx: WorkflowTransaction;
  readonly sourceType: BurnerLifecycleSourceType;
  readonly sourceId: string;
  readonly assetType: unknown;
  readonly assetNumber: unknown;
  readonly actionSources: readonly BurnerLifecycleActionSource[];
  readonly completedAt: string;
  readonly completedBy: Actor;
  readonly executionLevelMechanicalEvidence?: boolean;
}): Promise<BurnerBlockLifecycleWritePlan> => {
  const candidates: Array<{
    readonly row: ActionRow;
    readonly sourceModuleId: string | null;
    readonly sourceActionIndex: number;
    readonly mechanicalWorkContext: boolean;
  }> = [];
  const changeDecisions: BurnerBlockChangeDecision[] = [];
  for (const source of args.actionSources) {
    const changeDecision = moduleBurnerBlockChangeDecision(source);
    if (changeDecision != null) changeDecisions.push(changeDecision);
    let payload;
    try {
      payload = readComponentActionPayload(source.actionsJson, {
        field: source.sourceModuleId == null ?
          "actionsJson" : `module ${source.sourceModuleId} actionsJson`,
        allowMissing: source.actionsJson == null,
      });
    } catch (error) {
      if (error instanceof PersistedActionPayloadError) {
        throw new WorkflowError(
          "failed-precondition",
          "Saved component-action evidence needs repair before closure.",
          {
            reasonCode: "burner-block-lifecycle-actions-invalid",
            field: error.field,
          },
        );
      }
      throw error;
    }
    payload.rows.forEach((row, index) => {
      if (isBurnerBlockReplacement(row)) {
        candidates.push({
          row,
          sourceModuleId: source.sourceModuleId,
          sourceActionIndex: index,
          mechanicalWorkContext: source.discipline == null ?
            args.executionLevelMechanicalEvidence === true :
            normalizedKey(source.discipline) === "mechanical",
        });
      }
    });
  }
  for (const decision of changeDecisions) {
    const matchingCandidates = decision.burnerPosition == null ?
      candidates : candidates.filter((candidate) =>
        burnerPositionFromResponse(candidate.row.burnerPosition) ===
          decision.burnerPosition);
    if (decision.state === "changed" && matchingCandidates.length === 0) {
      throw new WorkflowError(
        "failed-precondition",
        "A module recording a burner-block change must include its governed replacement action.",
        {reasonCode: "burner-block-lifecycle-action-required"},
      );
    }
    if (decision.state === "unchanged" && matchingCandidates.length > 0) {
      throw new WorkflowError(
        "failed-precondition",
        "A module recording no burner-block change cannot include a burner-block replacement action.",
        {reasonCode: "burner-block-lifecycle-action-conflicts-with-response"},
      );
    }
  }
  if (candidates.length === 0) return {events: [], currentStates: []};
  const assetType = requiredText(args.assetType, "source.assetType");
  const assetNumber = positiveInteger(args.assetNumber, "source.assetNumber");
  const completedAt = parseInstant(args.completedAt, "completedAt");
  if (assetType !== "furnace") {
    throw new WorkflowError(
      "failed-precondition",
      "Burner-block replacement evidence is only valid on a Furnace.",
      {reasonCode: "burner-block-lifecycle-source-asset-invalid"},
    );
  }

  const events: Array<{path: string; data: JsonMap}> = [];
  for (const candidate of candidates) {
    const row = candidate.row;
    if (!candidate.mechanicalWorkContext) {
      throw new WorkflowError(
        "failed-precondition",
        "Burner-block installation must be recorded through Mechanical work.",
        {reasonCode: "burner-block-lifecycle-mechanical-work-required"},
      );
    }
    const position = positiveInteger(row.burnerPosition, "burnerPosition");
    if (position > 8 || row.status !== "resolved" ||
        !["sailRed", "purchased"].includes(String(row.burnerBlockSupplyMode)) ||
        !["newPart", "repaired", "revised"].includes(String(row.replacement))) {
      throw new WorkflowError(
        "failed-precondition",
        "Burner-block replacement must be resolved and its provenance complete.",
        {reasonCode: "burner-block-lifecycle-provenance-incomplete"},
      );
    }
    const supplyMode = row.burnerBlockSupplyMode as "sailRed" | "purchased";
    const supplierName = optionalText(
      row.burnerBlockSupplierName,
      "burnerBlockSupplierName",
    );
    const purchaseOrderNumber = optionalText(
      row.burnerBlockPurchaseOrderNumber,
      "burnerBlockPurchaseOrderNumber",
    );
    if (supplyMode !== "purchased" &&
        (supplierName != null || purchaseOrderNumber != null)) {
      throw new WorkflowError(
        "failed-precondition",
        "Supplier and PO evidence is only valid for purchased burner blocks.",
        {reasonCode: "burner-block-lifecycle-provenance-invalid"},
      );
    }
    const performedAt = parseInstant(row.createdAt, "action.createdAt");
    const performedByName = requiredText(
      row.performedBy,
      "action.performedBy",
    );
    if (Date.parse(performedAt) > Date.parse(completedAt) + 5 * 60 * 1000) {
      throw new WorkflowError(
        "failed-precondition",
        "Burner-block replacement time cannot be later than closure.",
        {reasonCode: "burner-block-lifecycle-time-invalid"},
      );
    }
    const target = await validateTarget({
      tx: args.tx,
      row,
      expectedAssetNumber: assetNumber,
    });
    const id = eventId([
      args.sourceType,
      args.sourceId,
      candidate.sourceModuleId ?? "execution",
      String(candidate.sourceActionIndex),
      String(row.id ?? ""),
      performedAt,
    ]);
    events.push({
      path: `burner_block_lifecycle_events/${id}`,
      data: {
        schemaVersion: 1,
        eventId: id,
        eventType: "replacement",
        assetClassId: target.assetClassId,
        assetClassCode: target.assetClassCode,
        assetClassName: target.assetClassName,
        assetInstanceId: target.assetInstanceId,
        assetInstanceName: target.assetInstanceName,
        assetNumber,
        hierarchyNodeId: target.nodeId,
        hierarchyNodeName: target.nodeName,
        hierarchyPath: target.hierarchyPath,
        componentTag: target.componentTag,
        burnerPosition: position,
        replacementDisposition: row.replacement as string,
        supplyMode,
        supplierName,
        purchaseOrderNumber,
        installationDiscipline: "mechanical",
        performedByName,
        sourceType: args.sourceType,
        sourceId: args.sourceId,
        sourceModuleId: candidate.sourceModuleId,
        sourceActionId: optionalText(row.id, "action.id"),
        sourceActionIndex: candidate.sourceActionIndex,
        actionPerformedAt: performedAt,
        completedAt,
        completedByUid: args.completedBy.uid,
        completedByName: args.completedBy.name,
        recordedAt: completedAt,
        version: 1,
        isDeleted: false,
      },
    });
  }
  const proposedCurrent = new Map<string, {path: string; data: JsonMap}>();
  for (const event of events) {
    const assetInstanceId = requiredText(
      event.data.assetInstanceId,
      "current.assetInstanceId",
    );
    const burnerPosition = positiveInteger(
      event.data.burnerPosition,
      "current.burnerPosition",
    );
    const projectionId = currentStateId(assetInstanceId, burnerPosition);
    const path = `burner_block_lifecycle_current/${projectionId}`;
    const data: JsonMap = {
      ...event.data,
      projectionSchemaVersion: 1,
      projectionId,
      currentEventId: event.data.eventId,
    };
    const pending = proposedCurrent.get(path);
    if (pending == null || isLaterLifecycleData(data, pending.data)) {
      proposedCurrent.set(path, {path, data});
    }
  }

  const currentStates: Array<{path: string; data: JsonMap}> = [];
  for (const proposed of proposedCurrent.values()) {
    const snapshot = await args.tx.get(proposed.path);
    if (!snapshot.exists) {
      currentStates.push(proposed);
      continue;
    }
    const current = snapshot.data;
    const projectionId = proposed.path.split("/").at(-1);
    if (current == null || current.projectionSchemaVersion !== 1 ||
        current.projectionId !== projectionId ||
        current.currentEventId !== current.eventId ||
        current.assetInstanceId !== proposed.data.assetInstanceId ||
        current.burnerPosition !== proposed.data.burnerPosition ||
        current.installationDiscipline !== "mechanical") {
      throw new WorkflowError(
        "failed-precondition",
        "The current burner-block lifecycle projection needs repair.",
        {reasonCode: "burner-block-lifecycle-current-invalid"},
      );
    }
    if (isLaterLifecycleData(proposed.data, current)) {
      currentStates.push(proposed);
    }
  }
  return {events, currentStates};
};

export const applyBurnerBlockLifecycleWritePlan = (
  tx: WorkflowTransaction,
  plan: BurnerBlockLifecycleWritePlan,
): void => {
  for (const event of plan.events) tx.create(event.path, event.data);
  for (const current of plan.currentStates) {
    tx.set(current.path, current.data);
  }
};
