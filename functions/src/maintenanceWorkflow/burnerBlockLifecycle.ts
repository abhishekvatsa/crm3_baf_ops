import {createHash} from "crypto";
import {persistedInstantMillis} from "../persistedInstant";

import {
  PersistedActionPayloadError,
  readComponentActionPayload,
} from "../persistedActionPayload";
import {
  PersistedWorkPayloadError,
  readFieldResponsePayload,
} from "../persistedWorkPayload";
import {WorkflowError} from "./errors";
import {stableJson} from "./utils";
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
  const parsed = new Date(persistedInstantMillis(value));
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
      typeof asset.assetClassName !== "string" || asset.assetClassName.trim().length === 0 ||
      typeof assetClass.name !== "string" || assetClass.name.trim().length === 0 ||
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

/**
 * One physical action, referenced twice, is still one installation.
 *
 * A closure supplies actions at execution scope and again at module scope, and
 * the same physical action can appear in both. The event identity includes
 * where the reference came from, so each reference became its own installation
 * in the asset's history while the current projection showed one. Identical
 * claims about one action collapse to the first; two claims that describe it
 * differently are a contradiction only a person can settle.
 */
const physicalActionKey = (data: JsonMap): string | null =>
  data.sourceActionId == null ? null : stableJson({
    sourceType: data.sourceType,
    sourceId: data.sourceId,
    sourceActionId: data.sourceActionId,
  });

/**
 * The claim two references make about one physical action. The time it was
 * performed, position, and target asset are claims, not parts of its identity.
 * Identity is scoped to the parent closure, so a disputed target cannot create
 * a second action and unrelated jobs can still use the same local action ID.
 * Original execution/module payloads retain every reference; coalescing only
 * prevents those retained references from counting as multiple installations.
 */
const sameLifecycleClaim = (left: JsonMap, right: JsonMap): boolean => {
  const comparable = (data: JsonMap): string => stableJson(
    Object.fromEntries(
      Object.entries(data).filter(([key]) =>
        key !== "eventId" && key !== "sourceModuleId" &&
        key !== "sourceActionIndex"),
    ),
  );
  return comparable(left) === comparable(right);
};

const currentStateId = (assetInstanceId: string, burnerPosition: number): string =>
  `bblc_${createHash("sha256")
    .update(`${assetInstanceId}|${burnerPosition}`, "utf8")
    .digest("hex").slice(0, 40)}`;

const isLaterLifecycleData = (candidate: JsonMap, current: JsonMap): boolean => {
  // Physical installation time determines what is installed now. A late
  // ordinary report remains history; it is not an implicit correction.
  const candidatePerformedAt = Date.parse(parseInstant(
    candidate.actionPerformedAt, "current.actionPerformedAt",
  ));
  const currentPerformedAt = Date.parse(parseInstant(
    current.actionPerformedAt, "current.actionPerformedAt",
  ));
  const candidateRecordedAt = Date.parse(parseInstant(
    candidate.recordedAt, "current.recordedAt",
  ));
  const currentRecordedAt = Date.parse(parseInstant(
    current.recordedAt, "current.recordedAt",
  ));
  if (candidatePerformedAt !== currentPerformedAt) {
    return candidatePerformedAt > currentPerformedAt;
  }
  if (candidateRecordedAt !== currentRecordedAt) {
    return candidateRecordedAt > currentRecordedAt;
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
  readonly recordedAt: string;
  readonly completedBy: Actor;
  readonly executionLevelMechanicalEvidence?: boolean;
}): Promise<BurnerBlockLifecycleWritePlan> => {
  const candidates: Array<{
    readonly row: ActionRow;
    readonly sourceModuleId: string | null;
    readonly sourceActionIndex: number;
    readonly sourceIndex: number;
    readonly mechanicalWorkContext: boolean;
  }> = [];
  const changeDecisions: Array<BurnerBlockChangeDecision & {
    readonly sourceIndex: number;
  }> = [];
  for (const [sourceIndex, source] of args.actionSources.entries()) {
    const changeDecision = moduleBurnerBlockChangeDecision(source);
    if (changeDecision != null) {
      changeDecisions.push({...changeDecision, sourceIndex});
    }
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
          sourceIndex,
          mechanicalWorkContext: source.discipline == null ?
            args.executionLevelMechanicalEvidence === true :
            normalizedKey(source.discipline) === "mechanical",
        });
      }
    });
  }
  for (const decision of changeDecisions) {
    // A declaration belongs to its module. Another MODULE's action must
    // neither satisfy a missing replacement nor veto an honest "unchanged"
    // answer, even when both refer to the same burner position.
    //
    // Execution-level actions are deliberately still in scope. The operator
    // can record component work either inside the module or on the job
    // completion screen, and `executionLevelMechanicalEvidence` exists so the
    // latter can support a module declaration. Excluding it would both force
    // the same repair to be entered twice and stop an execution-level
    // replacement from contradicting an "unchanged" answer, which is the
    // check that catches a misdeclaration.
    const matchingCandidates = candidates.filter((candidate) =>
      (candidate.sourceIndex === decision.sourceIndex ||
        candidate.sourceModuleId == null) &&
      (decision.burnerPosition == null ||
        burnerPositionFromResponse(candidate.row.burnerPosition) ===
          decision.burnerPosition));
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
  const recordedAt = parseInstant(args.recordedAt, "recordedAt");
  // Work is often entered after it finished, and the two are different facts:
  // the physical completion, and when the electronic record came into being.
  // A recording cannot precede the completion it records, but it may follow
  // it, and a late entry must not be dressed as contemporaneous evidence.
  if (recordedAt < completedAt) {
    throw new WorkflowError(
      "failed-precondition",
      "Burner-block lifecycle recording time precedes its authoritative closure time.",
      {reasonCode: "burner-block-lifecycle-closure-time-mismatch"},
    );
  }
  if (assetType !== "furnace") {
    throw new WorkflowError(
      "failed-precondition",
      "Burner-block replacement evidence is only valid on a Furnace.",
      {reasonCode: "burner-block-lifecycle-source-asset-invalid"},
    );
  }

  const events: Array<{path: string; data: JsonMap}> = [];
  const physicalActions = new Map<string, {path: string; data: JsonMap}>();
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
    const data: JsonMap = {
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
        recordedAt,
        version: 1,
        isDeleted: false,
    };
    const planned = {path: `burner_block_lifecycle_events/${id}`, data};
    const physicalKey = physicalActionKey(data);
    const alreadyPlanned = physicalKey == null ?
      undefined : physicalActions.get(physicalKey);
    if (alreadyPlanned != null) {
      if (!sameLifecycleClaim(alreadyPlanned.data, data)) {
        throw new WorkflowError(
          "failed-precondition",
          "One burner-block replacement action is described two different ways in this closure.",
          {reasonCode: "burner-block-lifecycle-action-conflict"},
        );
      }
      continue;
    }
    if (physicalKey != null) physicalActions.set(physicalKey, planned);
    events.push(planned);
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

export const BURNER_BLOCK_CORRECTIONS =
  "burner_block_lifecycle_corrections";

export interface BurnerBlockCorrectionWritePlan {
  readonly correction: {readonly path: string; readonly data: JsonMap};
  readonly currentState: {readonly path: string; readonly data: JsonMap};
  readonly correctedEvent: JsonMap;
  readonly supersededCorrection: JsonMap | null;
  readonly previousCurrentState: JsonMap | null;
}

const requireCurrentProjection = async (args: {
  readonly tx: WorkflowTransaction;
  readonly assetInstanceId: string;
  readonly burnerPosition: number;
  readonly expectedCurrentEventId: string;
}): Promise<{
  readonly projectionId: string;
  readonly snapshot: Awaited<ReturnType<WorkflowTransaction["get"]>>;
}> => {
  const projectionId = currentStateId(
    args.assetInstanceId,
    args.burnerPosition,
  );
  const snapshot = await args.tx.get(
    `burner_block_lifecycle_current/${projectionId}`,
  );
  const data = snapshot.data;
  if (!snapshot.exists || data == null ||
      data.projectionSchemaVersion !== 1 ||
      data.projectionId !== projectionId ||
      data.currentEventId !== data.eventId ||
      data.assetInstanceId !== args.assetInstanceId ||
      data.burnerPosition !== args.burnerPosition ||
      data.installationDiscipline !== "mechanical") {
    throw new WorkflowError(
      "failed-precondition",
      "The current burner-block lifecycle projection is missing or inconsistent.",
      {reasonCode: "burner-block-lifecycle-current-invalid", projectionId},
    );
  }
  if (data.currentEventId !== args.expectedCurrentEventId) {
    throw new WorkflowError(
      "workflow-version-conflict",
      "The burner-block installation changed before this correction was applied.",
      {
        reasonCode: "burner-block-lifecycle-current-version-conflict",
        projectionId,
        expectedCurrentEventId: args.expectedCurrentEventId,
        actualCurrentEventId: data.currentEventId,
      },
    );
  }
  return {projectionId, snapshot};
};

/** The correction in force for an event: the one nothing else supersedes. */
const effectiveCorrection = (
  corrections: readonly JsonMap[],
  eventId: string,
): JsonMap | null => {
  const superseded = new Set(
    corrections
      .map((data) => data.supersedesCorrectionId)
      .filter((value): value is string => typeof value === "string"),
  );
  const live = corrections.filter((data) =>
    data.correctsEventId === eventId &&
    !superseded.has(String(data.correctionId)));
  if (live.length > 1) {
    throw new WorkflowError(
      "failed-precondition",
      "This installation has more than one correction in force.",
      {reasonCode: "burner-block-lifecycle-corrections-conflict", eventId},
    );
  }
  return live[0] ?? null;
};

/** What an event says now: its own time, or the time a correction gave it. */
const correctedInstallationTime = (
  event: JsonMap,
  corrections: readonly JsonMap[],
): string => {
  const correction = effectiveCorrection(
    corrections,
    requiredText(event.eventId, "current.eventId"),
  );
  return parseInstant(
    correction == null ?
      event.actionPerformedAt : correction.correctedActionPerformedAt,
    "current.actionPerformedAt",
  );
};

/**
 * Putting right an installation time that was written down wrong.
 *
 * Neither obvious repair is honest. Recording another replacement invents a
 * physical event that never happened and adds one to the count of times that
 * position was changed; editing the original destroys what somebody actually
 * wrote. So a correction is neither: it is its own record, in its own
 * collection, naming the event it corrects and saying why.
 *
 * Keeping it out of the lifecycle event collection is deliberate. Installed
 * handsets read every document in that collection through a decoder that
 * refuses fields it does not know, so a correction filed there would have
 * darkened the whole burner-block history on the plant rather than adding a
 * line to it. What those handsets do see is the rebuilt current installation,
 * which is the part that matters operationally.
 *
 * The rebuild is the reason this cannot reuse the ordinary write plan. That
 * plan only ever moves the current installation forward; a corrected date can
 * move it back, to an earlier replacement that was the true one all along.
 */
export const prepareBurnerBlockInstallationCorrection = async (args: {
  readonly tx: WorkflowTransaction;
  readonly eventId: string;
  readonly expectedCurrentEventId: string;
  readonly correctedActionPerformedAt: unknown;
  readonly reason: unknown;
  readonly supersedesCorrectionId: string | null;
  readonly correctedBy: {readonly uid: string | null; readonly name: string};
  readonly correctedAt: unknown;
  readonly correctionId: string;
}): Promise<BurnerBlockCorrectionWritePlan> => {
  const reason = requiredText(args.reason, "reason");
  const correctedActionPerformedAt = parseInstant(
    args.correctedActionPerformedAt,
    "correctedActionPerformedAt",
  );
  const correctedAt = parseInstant(args.correctedAt, "correctedAt");
  if (Date.parse(correctedActionPerformedAt) > Date.parse(correctedAt)) {
    throw new WorkflowError(
      "failed-precondition",
      "A corrected installation time cannot be later than the correction time.",
      {reasonCode: "burner-block-lifecycle-correction-chronology-invalid"},
    );
  }
  const original = await args.tx.get(
    `burner_block_lifecycle_events/${args.eventId}`,
  );
  if (!original.exists || original.data == null ||
      original.data.isDeleted === true) {
    throw new WorkflowError(
      "failed-precondition",
      "That burner-block lifecycle event was not found.",
      {
        reasonCode: "burner-block-lifecycle-event-unknown",
        eventId: args.eventId,
      },
    );
  }
  const assetInstanceId = requiredText(
    original.data.assetInstanceId,
    "current.assetInstanceId",
  );
  const originalCompletedAt = parseInstant(
    original.data.completedAt,
    "current.completedAt",
  );
  // Installed clients still validate the shared current projection using the
  // raw event's closure chronology. Refuse a correction that would make that
  // projection unreadable; a mistaken closure needs a separately governed
  // correction rather than an incompatible shared record.
  if (Date.parse(correctedActionPerformedAt) >
      Date.parse(originalCompletedAt) + 5 * 60 * 1000) {
    throw new WorkflowError(
      "failed-precondition",
      "The corrected installation time would make the current projection incompatible with installed clients.",
      {reasonCode: "burner-block-lifecycle-correction-after-completion"},
    );
  }
  const burnerPosition = positiveInteger(
    original.data.burnerPosition,
    "current.burnerPosition",
  );
  const current = await requireCurrentProjection({
    tx: args.tx,
    assetInstanceId,
    burnerPosition,
    expectedCurrentEventId: requiredText(
      args.expectedCurrentEventId,
      "expectedCurrentEventId",
    ),
  });
  const [siblings, storedCorrections] = await Promise.all([
    args.tx.query("burner_block_lifecycle_events", [
      {field: "assetInstanceId", op: "==", value: assetInstanceId},
      {field: "burnerPosition", op: "==", value: burnerPosition},
    ]),
    args.tx.query(BURNER_BLOCK_CORRECTIONS, [
      {field: "assetInstanceId", op: "==", value: assetInstanceId},
      {field: "burnerPosition", op: "==", value: burnerPosition},
    ]),
  ]);
  const surviving = siblings
    .map((row) => row.data)
    .filter((data): data is JsonMap => data != null && data.isDeleted !== true);
  const corrections = storedCorrections
    .map((row) => row.data)
    .filter((data): data is JsonMap => data != null);

  // A correction that is itself wrong is corrected in turn, but only by
  // somebody who knows what is in force. Naming the wrong predecessor - or
  // none at all - means the caller was looking at something else.
  const inForce = effectiveCorrection(corrections, args.eventId);
  const named = args.supersedesCorrectionId;
  if ((inForce == null ? null : String(inForce.correctionId)) !== named) {
    throw new WorkflowError(
      "failed-precondition",
      inForce == null ?
        "That installation time has not been corrected before." :
        "This installation time has already been corrected. " +
          "Correct the correction that is in force.",
      {
        reasonCode: "burner-block-lifecycle-correction-stale",
        eventId: args.eventId,
        correctionInForce: inForce == null ? null : inForce.correctionId,
      },
    );
  }
  if (correctedInstallationTime(original.data, corrections) ===
      correctedActionPerformedAt) {
    // Restating the time already in force corrects nothing, and the record it
    // would leave behind would claim a correction that never happened.
    throw new WorkflowError(
      "failed-precondition",
      "That is the installation time already in force for this event.",
      {
        reasonCode: "burner-block-lifecycle-correction-no-change",
        eventId: args.eventId,
      },
    );
  }

  const correction: JsonMap = {
    schemaVersion: 1,
    correctionId: args.correctionId,
    correctsEventId: args.eventId,
    expectedCurrentEventId: args.expectedCurrentEventId,
    supersedesCorrectionId: named,
    assetInstanceId,
    burnerPosition,
    assetClassId: original.data.assetClassId ?? null,
    assetNumber: original.data.assetNumber ?? null,
    componentTag: original.data.componentTag ?? null,
    recordedActionPerformedAt: parseInstant(
      original.data.actionPerformedAt,
      "current.actionPerformedAt",
    ),
    correctedActionPerformedAt,
    reason,
    correctedAt,
    correctedByUid: args.correctedBy.uid,
    correctedByName: args.correctedBy.name,
    version: 1,
  };

  // Rebuilt from every surviving event at this position, each read at the
  // time in force for it, so the answer does not depend on which way the
  // corrected date moved.
  const effective = [...corrections, correction];
  let winner: JsonMap | null = null;
  for (const data of surviving) {
    const candidate: JsonMap = {
      ...data,
      actionPerformedAt: correctedInstallationTime(data, effective),
    };
    if (winner == null || isLaterLifecycleData(candidate, winner)) {
      winner = candidate;
    }
  }
  if (winner == null) {
    throw new WorkflowError(
      "failed-precondition",
      "Correcting this event would leave the position with no installation.",
      {reasonCode: "burner-block-lifecycle-correction-empties-position"},
    );
  }
  return {
    correction: {
      path: `${BURNER_BLOCK_CORRECTIONS}/${args.correctionId}`,
      data: correction,
    },
    currentState: {
      path: `burner_block_lifecycle_current/${current.projectionId}`,
      data: {
        ...winner,
        projectionSchemaVersion: 1,
        projectionId: current.projectionId,
        currentEventId: winner.eventId,
      },
    },
    correctedEvent: original.data,
    supersededCorrection: inForce,
    previousCurrentState: current.snapshot.data ?? null,
  };
};

export const applyBurnerBlockInstallationCorrection = (
  tx: WorkflowTransaction,
  plan: BurnerBlockCorrectionWritePlan,
): void => {
  tx.create(plan.correction.path, plan.correction.data);
  tx.set(plan.currentState.path, plan.currentState.data);
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
