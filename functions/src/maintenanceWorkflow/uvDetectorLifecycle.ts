import {createHash} from "crypto";

import {
  PersistedActionPayloadError,
  readComponentActionPayload,
} from "../persistedActionPayload";
import {WorkflowError} from "./errors";
import {WorkflowTransaction} from "./store";
import {Actor, JsonMap} from "./types";

type ActionRow = Record<string, unknown>;

type UvLifecycleSourceType =
  | "maintenanceIssue"
  | "legacyPlannedJob"
  | "workflowPlannedJob";

interface UvLifecycleActionSource {
  readonly sourceModuleId: string | null;
  readonly discipline?: unknown;
  readonly actionsJson: unknown;
}

export interface UvDetectorLifecycleWritePlan {
  readonly events: readonly {
    readonly path: string;
    readonly data: JsonMap;
  }[];
  readonly currentStates: readonly {
    readonly path: string;
    readonly data: JsonMap;
  }[];
}

interface ValidatedUvTarget {
  readonly assetClassId: string;
  readonly assetClassCode: string;
  readonly assetClassName: string;
  readonly assetInstanceId: string;
  readonly assetInstanceName: string;
  readonly nodeId: string | null;
  readonly nodeName: string;
  readonly hierarchyPath: readonly string[];
  readonly componentTag: string | null;
}

const requiredText = (value: unknown, field: string): string => {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new WorkflowError(
      "failed-precondition",
      `UV-detector lifecycle ${field} is missing.`,
      {reasonCode: "uv-detector-lifecycle-invalid", field},
    );
  }
  return value.trim();
};

const optionalText = (value: unknown, field: string): string | null => {
  if (value == null) return null;
  const parsed = requiredText(value, field);
  if (parsed.length > 160) {
    throw new WorkflowError(
      "failed-precondition",
      `UV-detector lifecycle ${field} is too long.`,
      {reasonCode: "uv-detector-lifecycle-invalid", field},
    );
  }
  return parsed;
};

const positiveInteger = (value: unknown, field: string): number => {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 1) {
    throw new WorkflowError(
      "failed-precondition",
      `UV-detector lifecycle ${field} is invalid.`,
      {reasonCode: "uv-detector-lifecycle-invalid", field},
    );
  }
  return value;
};

const record = (value: unknown, field: string): ActionRow => {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new WorkflowError(
      "failed-precondition",
      `UV-detector lifecycle ${field} is invalid.`,
      {reasonCode: "uv-detector-lifecycle-invalid", field},
    );
  }
  return value as ActionRow;
};

const stringList = (value: unknown, field: string): string[] => {
  if (!Array.isArray(value) || value.length === 0 || value.length > 20 ||
      value.some((item) =>
        typeof item !== "string" || item.trim().length === 0)) {
    throw new WorkflowError(
      "failed-precondition",
      `UV-detector lifecycle ${field} is invalid.`,
      {reasonCode: "uv-detector-lifecycle-invalid", field},
    );
  }
  return value.map((item) => (item as string).trim());
};

const normalizedKey = (value: unknown): string =>
  typeof value === "string" ?
    value.trim().toLowerCase().replace(/[^a-z0-9]+/g, "") : "";

const normalizedTag = (value: string): string =>
  value.trim().toUpperCase().replace(/[^A-Z0-9]+/g, "");

const isUvDetectorIdentity = (...values: unknown[]): boolean => {
  const identity = values.flatMap((value) =>
    Array.isArray(value) ? value : [value])
    .map((value) => String(value ?? ""))
    .join(" ")
    .toLowerCase();
  return (identity.includes("uv") &&
      ["detector", "sensor", "scanner"].some((part) =>
        identity.includes(part))) || identity.includes("flame detector");
};

const isUvDetectorReplacement = (row: ActionRow): boolean => {
  if (row.burnerActionCode === "uvDetectorReplacement") return true;
  return row.burnerPosition != null &&
    (row.actionType ?? row.action) === "replacement" &&
    isUvDetectorIdentity(
      row.component,
      (row.assetHierarchyRef as ActionRow | null)?.nodeName,
      (row.assetHierarchyRef as ActionRow | null)?.hierarchyPath,
    );
};

const establishesServiceableUvCondition = (row: ActionRow): boolean =>
  row.burnerActionCode !== "uvDetectorReplacement" ||
  row.burnerOutcome === "returnedToService";

const parseInstant = (value: unknown, field: string): string => {
  const text = requiredText(value, field);
  const parsed = new Date(text);
  if (!Number.isFinite(parsed.getTime())) {
    throw new WorkflowError(
      "failed-precondition",
      `UV-detector lifecycle ${field} is invalid.`,
      {reasonCode: "uv-detector-lifecycle-invalid", field},
    );
  }
  return parsed.toISOString();
};

const parseSourceReference = (value: unknown): ActionRow => {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new WorkflowError(
      "failed-precondition",
      "The UV replacement source has no governed Furnace identity.",
      {reasonCode: "uv-detector-lifecycle-source-target-missing"},
    );
  }
  try {
    return record(JSON.parse(value), "sourceAssetReferenceJson");
  } catch (error) {
    if (error instanceof WorkflowError) throw error;
    throw new WorkflowError(
      "failed-precondition",
      "The UV replacement source Furnace identity is malformed.",
      {reasonCode: "uv-detector-lifecycle-source-target-invalid"},
    );
  }
};

const validatePhysicalAsset = async (args: {
  readonly tx: WorkflowTransaction;
  readonly reference: ActionRow;
  readonly expectedAssetNumber: number;
}): Promise<{
  readonly assetClassId: string;
  readonly assetClassCode: string;
  readonly assetClassName: string;
  readonly assetInstanceId: string;
  readonly assetInstanceName: string;
}> => {
  const classId = requiredText(
    args.reference.assetClassId,
    "assetHierarchyRef.assetClassId",
  );
  const assetId = requiredText(
    args.reference.assetInstanceId,
    "assetHierarchyRef.assetInstanceId",
  );
  const [classSnapshot, assetSnapshot] = await Promise.all([
    args.tx.get(`asset_classes/${classId}`),
    args.tx.get(`asset_instances/${assetId}`),
  ]);
  const assetClass = classSnapshot.data;
  const asset = assetSnapshot.data;
  if (!classSnapshot.exists || assetClass == null ||
      assetClass.schemaVersion !== 1 || assetClass.assetClassId !== classId ||
      assetClass.status !== "active" ||
      assetClass.legacyAssetTypeKey !== "furnace" ||
      !assetSnapshot.exists || asset == null || asset.schemaVersion !== 1 ||
      asset.assetInstanceId !== assetId || asset.assetClassId !== classId ||
      asset.status !== "active" ||
      asset.assetNumber !== args.expectedAssetNumber ||
      asset.assetClassCode !== assetClass.code ||
      asset.assetClassName !== assetClass.name) {
    throw new WorkflowError(
      "aborted",
      "The governed Furnace identity changed before UV replacement closure.",
      {reasonCode: "uv-detector-lifecycle-source-target-changed"},
    );
  }
  return {
    assetClassId: classId,
    assetClassCode: requiredText(assetClass.code, "assetClass.code"),
    assetClassName: requiredText(assetClass.name, "assetClass.name"),
    assetInstanceId: assetId,
    assetInstanceName: requiredText(asset.name, "asset.name"),
  };
};

const validateTarget = async (args: {
  readonly tx: WorkflowTransaction;
  readonly row: ActionRow;
  readonly sourceAssetReferenceJson?: unknown;
  readonly expectedAssetNumber: number;
  readonly burnerPosition: number;
}): Promise<ValidatedUvTarget> => {
  const rawReference = args.row.assetHierarchyRef;
  if (rawReference == null) {
    if (args.row.burnerActionCode !== "uvDetectorReplacement") {
      throw new WorkflowError(
        "failed-precondition",
        "UV replacement must target the governed UV component on the Furnace.",
        {reasonCode: "uv-detector-lifecycle-target-invalid"},
      );
    }
    const asset = await validatePhysicalAsset({
      tx: args.tx,
      reference: parseSourceReference(args.sourceAssetReferenceJson),
      expectedAssetNumber: args.expectedAssetNumber,
    });
    const nodeName = `UV detector at Burner ${args.burnerPosition}`;
    return {
      ...asset,
      nodeId: null,
      nodeName,
      hierarchyPath: ["Furnace", "Burner system", nodeName],
      componentTag: null,
    };
  }

  const reference = record(rawReference, "assetHierarchyRef");
  const scope = requiredText(reference.scope, "assetHierarchyRef.scope");
  if (!["componentDefinitionOnAsset", "installedComponent"].includes(scope)) {
    throw new WorkflowError(
      "failed-precondition",
      "UV replacement must target a governed component on the Furnace.",
      {reasonCode: "uv-detector-lifecycle-target-invalid"},
    );
  }
  const supportedSchemas = scope === "componentDefinitionOnAsset" ? [4] : [2, 3];
  if (!supportedSchemas.includes(reference.schemaVersion as number)) {
    throw new WorkflowError(
      "failed-precondition",
      "UV replacement uses an unsupported hierarchy reference.",
      {reasonCode: "uv-detector-lifecycle-target-invalid"},
    );
  }
  const asset = await validatePhysicalAsset({
    tx: args.tx,
    reference,
    expectedAssetNumber: args.expectedAssetNumber,
  });
  const nodeId = requiredText(reference.nodeId, "assetHierarchyRef.nodeId");
  const nodeVersion = positiveInteger(
    reference.nodeVersion,
    "assetHierarchyRef.nodeVersion",
  );
  const assetVersion = positiveInteger(
    reference.assetInstanceVersion,
    "assetHierarchyRef.assetInstanceVersion",
  );
  const nodeSnapshot = await args.tx.get(`asset_hierarchy_nodes/${nodeId}`);
  const node = nodeSnapshot.data;
  if (!nodeSnapshot.exists || node == null || node.schemaVersion !== 1 ||
      node.nodeId !== nodeId || node.assetClassId !== asset.assetClassId ||
      node.status !== "active" || node.version !== nodeVersion ||
      !["component", "subcomponent"].includes(String(node.nodeType)) ||
      !isUvDetectorIdentity(node.name, node.hierarchyPath)) {
    throw new WorkflowError(
      "aborted",
      "The governed Furnace UV-detector target changed before closure.",
      {reasonCode: "uv-detector-lifecycle-target-changed"},
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
        component.assetClassId !== asset.assetClassId ||
        component.assetInstanceId !== asset.assetInstanceId ||
        component.assetNumber !== args.expectedAssetNumber ||
        component.status !== "active" || component.version !== componentVersion ||
        component.assetInstanceVersionAtMutation !== assetVersion ||
        component.definitionNodeId !== nodeId ||
        component.definitionNodeVersion !== nodeVersion ||
        componentTag == null || actionTag == null ||
        normalizedTag(componentTag) !== normalizedTag(actionTag)) {
      throw new WorkflowError(
        "aborted",
        "The installed UV-detector tag changed before closure.",
        {reasonCode: "uv-detector-lifecycle-tag-changed"},
      );
    }
  } else {
    const assetSnapshot = await args.tx.get(
      `asset_instances/${asset.assetInstanceId}`,
    );
    const actionTag = optionalText(args.row.tag, "action.tag");
    if (assetSnapshot.data?.version !== assetVersion ||
        (actionTag != null &&
          (componentTag == null ||
            normalizedTag(actionTag) !== normalizedTag(componentTag)))) {
      throw new WorkflowError(
        "aborted",
        "The Furnace UV hierarchy target changed before closure.",
        {reasonCode: "uv-detector-lifecycle-target-changed"},
      );
    }
  }

  const hierarchyPath = stringList(node.hierarchyPath, "hierarchyPath");
  if (requiredText(args.row.component, "action.component") !== node.name ||
      !isUvDetectorIdentity(args.row.component, hierarchyPath)) {
    throw new WorkflowError(
      "failed-precondition",
      "The component action does not match the governed UV-detector target.",
      {reasonCode: "uv-detector-lifecycle-target-mismatch"},
    );
  }
  return {
    ...asset,
    nodeId,
    nodeName: requiredText(node.name, "node.name"),
    hierarchyPath,
    componentTag,
  };
};

const eventId = (parts: readonly string[]): string =>
  `uvl_${createHash("sha256").update(parts.join("|"), "utf8")
    .digest("hex").slice(0, 40)}`;

const currentStateId = (assetInstanceId: string, burnerPosition: number): string =>
  `uvlc_${createHash("sha256")
    .update(`${assetInstanceId}|${burnerPosition}`, "utf8")
    .digest("hex").slice(0, 40)}`;

const isLaterLifecycleData = (candidate: JsonMap, current: JsonMap): boolean => {
  const candidateRecordedAt = Date.parse(parseInstant(
    candidate.recordedAt,
    "current.recordedAt",
  ));
  const currentRecordedAt = Date.parse(parseInstant(
    current.recordedAt,
    "current.recordedAt",
  ));
  if (candidateRecordedAt !== currentRecordedAt) {
    return candidateRecordedAt > currentRecordedAt;
  }
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
  return requiredText(candidate.eventId, "current.eventId") >
    requiredText(current.eventId, "current.eventId");
};

export const prepareUvDetectorLifecycleWritePlan = async (args: {
  readonly tx: WorkflowTransaction;
  readonly sourceType: UvLifecycleSourceType;
  readonly sourceId: string;
  readonly sourceAssetReferenceJson?: unknown;
  readonly assetType: unknown;
  readonly assetNumber: unknown;
  readonly actionSources: readonly UvLifecycleActionSource[];
  readonly completedAt: string;
  readonly recordedAt: string;
  readonly completedBy: Actor;
  readonly executionLevelInstrumentationEvidence?: boolean;
}): Promise<UvDetectorLifecycleWritePlan> => {
  const candidates: Array<{
    readonly row: ActionRow;
    readonly sourceModuleId: string | null;
    readonly sourceActionIndex: number;
    readonly instrumentationWorkContext: boolean;
  }> = [];
  for (const source of args.actionSources) {
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
            reasonCode: "uv-detector-lifecycle-actions-invalid",
            field: error.field,
          },
        );
      }
      throw error;
    }
    payload.rows.forEach((row, index) => {
      if (!isUvDetectorReplacement(row) ||
          !establishesServiceableUvCondition(row)) return;
      candidates.push({
        row,
        sourceModuleId: source.sourceModuleId,
        sourceActionIndex: index,
        instrumentationWorkContext: source.discipline == null ?
          args.executionLevelInstrumentationEvidence === true :
          normalizedKey(source.discipline) === "instrumentation",
      });
    });
  }
  if (candidates.length === 0) return {events: [], currentStates: []};

  const assetType = requiredText(args.assetType, "source.assetType");
  const assetNumber = positiveInteger(args.assetNumber, "source.assetNumber");
  const completedAt = parseInstant(args.completedAt, "completedAt");
  const recordedAt = parseInstant(args.recordedAt, "recordedAt");
  if (assetType !== "furnace") {
    throw new WorkflowError(
      "failed-precondition",
      "UV-detector replacement evidence is only valid on a Furnace.",
      {reasonCode: "uv-detector-lifecycle-source-asset-invalid"},
    );
  }

  const events: Array<{path: string; data: JsonMap}> = [];
  for (const candidate of candidates) {
    const row = candidate.row;
    if (!candidate.instrumentationWorkContext) {
      throw new WorkflowError(
        "failed-precondition",
        "UV-detector installation must be recorded through I&A work.",
        {reasonCode: "uv-detector-lifecycle-instrumentation-work-required"},
      );
    }
    const position = positiveInteger(row.burnerPosition, "burnerPosition");
    if (position > 8 || row.status !== "resolved" ||
        !["newPart", "repaired", "revised"].includes(String(row.replacement))) {
      throw new WorkflowError(
        "failed-precondition",
        "UV-detector replacement must be resolved and identify its numbered burner and disposition.",
        {reasonCode: "uv-detector-lifecycle-evidence-incomplete"},
      );
    }
    const performedAt = parseInstant(row.createdAt, "action.createdAt");
    if (Date.parse(performedAt) > Date.parse(completedAt) + 5 * 60 * 1000) {
      throw new WorkflowError(
        "failed-precondition",
        "UV-detector replacement time cannot be later than closure.",
        {reasonCode: "uv-detector-lifecycle-time-invalid"},
      );
    }
    const target = await validateTarget({
      tx: args.tx,
      row,
      sourceAssetReferenceJson: args.sourceAssetReferenceJson,
      expectedAssetNumber: assetNumber,
      burnerPosition: position,
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
      path: `uv_detector_lifecycle_events/${id}`,
      data: {
        schemaVersion: 1,
        eventId: id,
        eventType: "replacement",
        resultingCondition: "serviceable",
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
        installationDiscipline: "instrumentation",
        performedByName: requiredText(row.performedBy, "action.performedBy"),
        sourceType: args.sourceType,
        sourceId: args.sourceId,
        sourceModuleId: candidate.sourceModuleId,
        sourceActionId: optionalText(row.id, "action.id"),
        sourceActionIndex: candidate.sourceActionIndex,
        actionPerformedAt: performedAt,
        completedAt,
        completedByUid: args.completedBy.uid,
        completedByName: args.completedBy.name,
        recordedAt,
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
    const path = `uv_detector_lifecycle_current/${projectionId}`;
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
        current.resultingCondition !== "serviceable" ||
        current.installationDiscipline !== "instrumentation") {
      throw new WorkflowError(
        "failed-precondition",
        "The current UV-detector lifecycle projection needs repair.",
        {reasonCode: "uv-detector-lifecycle-current-invalid"},
      );
    }
    if (isLaterLifecycleData(proposed.data, current)) {
      currentStates.push(proposed);
    }
  }
  return {events, currentStates};
};

export const applyUvDetectorLifecycleWritePlan = (
  tx: WorkflowTransaction,
  plan: UvDetectorLifecycleWritePlan,
): void => {
  for (const event of plan.events) tx.create(event.path, event.data);
  for (const current of plan.currentStates) tx.set(current.path, current.data);
};
