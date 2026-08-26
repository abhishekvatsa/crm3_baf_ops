import {createHash} from "crypto";
import {WorkflowError} from "./errors";
import {WorkflowTransaction} from "./store";
import {Actor, JsonMap, LaneKey} from "./types";
import {persistedInstantText} from "./utils";

export interface MaintenanceResetCounter {
  readonly key: string;
  readonly label: string;
  readonly thresholdDays: number | null;
}

export interface FrozenMaintenanceClass {
  readonly schemaVersion: 1;
  readonly definitionId: string;
  readonly definitionVersion: number;
  readonly code: string;
  readonly title: string;
  readonly assetTypeKeys: readonly string[];
  readonly assetClassIds: readonly string[];
  readonly resetCounters: readonly MaintenanceResetCounter[];
  readonly principalLaneKey: LaneKey;
}

export interface MaintenanceAssetIdentity {
  readonly assetIdentityKey: string;
  readonly assetTypeKey: string;
  readonly assetNumber: number | null;
  readonly assetClassId: string | null;
  readonly assetInstanceId: string | null;
}

export interface MaintenanceCompletionWritePlan {
  readonly eventId: string;
  readonly eventPath: string;
  readonly eventData: JsonMap;
  readonly sourcePath: string;
  readonly sourceData: JsonMap;
  readonly dueStates: readonly {readonly path: string; readonly data: JsonMap}[];
}

const documentId = (value: unknown, field: string): string => {
  if (typeof value !== "string") {
    throw new WorkflowError("failed-precondition", `${field} is missing.`);
  }
  const parsed = value.trim();
  if (parsed.length === 0 || parsed.length > 160 || parsed === "." ||
      parsed === ".." || parsed.includes("/")) {
    throw new WorkflowError("failed-precondition", `${field} is invalid.`);
  }
  return parsed;
};

const optionalDocumentId = (value: unknown, field: string): string | null =>
  value == null ? null : documentId(value, field);

const positiveVersion = (value: unknown, field: string): number => {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 1) {
    throw new WorkflowError("failed-precondition", `${field} is invalid.`);
  }
  return value;
};

const boundedText = (
  value: unknown,
  field: string,
  maximum: number,
): string => {
  if (typeof value !== "string") {
    throw new WorkflowError("failed-precondition", `${field} is missing.`);
  }
  const parsed = value.trim();
  if (parsed.length === 0 || parsed.length > maximum) {
    throw new WorkflowError("failed-precondition", `${field} is invalid.`);
  }
  return parsed;
};

const stringList = (
  value: unknown,
  field: string,
  maximumItems: number,
  allowEmpty = false,
): string[] => {
  if (!Array.isArray(value) || (!allowEmpty && value.length === 0) ||
      value.length > maximumItems) {
    throw new WorkflowError("failed-precondition", `${field} is invalid.`);
  }
  const parsed = value.map((item) => documentId(item, field));
  if (new Set(parsed).size !== parsed.length) {
    throw new WorkflowError("failed-precondition", `${field} contains duplicates.`);
  }
  return parsed;
};

const parseCounter = (value: unknown, index: number): MaintenanceResetCounter => {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new WorkflowError(
      "failed-precondition",
      `maintenanceClassification.resetCounters[${index}] is invalid.`,
    );
  }
  const data = value as Record<string, unknown>;
  const keys = Object.keys(data).sort().join(",");
  if (keys !== "key,label,thresholdDays") {
    throw new WorkflowError(
      "failed-precondition",
      `maintenanceClassification.resetCounters[${index}] has an unsupported shape.`,
    );
  }
  const key = documentId(data.key, `resetCounters[${index}].key`);
  if (!/^[A-Z0-9][A-Z0-9_-]+$/.test(key)) {
    throw new WorkflowError(
      "failed-precondition",
      `maintenanceClassification.resetCounters[${index}].key is invalid.`,
    );
  }
  const threshold = data.thresholdDays;
  if (threshold != null &&
      (typeof threshold !== "number" || !Number.isSafeInteger(threshold) ||
       threshold < 1 || threshold > 3650)) {
    throw new WorkflowError(
      "failed-precondition",
      `maintenanceClassification.resetCounters[${index}].thresholdDays is invalid.`,
    );
  }
  return {
    key,
    label: boundedText(data.label, `resetCounters[${index}].label`, 120),
    thresholdDays: threshold as number | null,
  };
};

export const parseFrozenMaintenanceClass = (
  value: unknown,
): FrozenMaintenanceClass => {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new WorkflowError(
      "failed-precondition",
      "The frozen maintenance classification is malformed.",
      {reasonCode: "maintenance-classification-invalid"},
    );
  }
  const data = value as Record<string, unknown>;
  const keys = Object.keys(data).sort().join(",");
  if (keys !== [
    "assetClassIds", "assetTypeKeys", "code", "definitionId",
    "definitionVersion", "principalLaneKey", "resetCounters",
    "schemaVersion", "title",
  ].sort().join(",") || data.schemaVersion !== 1) {
    throw new WorkflowError(
      "failed-precondition",
      "The frozen maintenance classification has an unsupported shape.",
      {reasonCode: "maintenance-classification-invalid"},
    );
  }
  const counters = Array.isArray(data.resetCounters) ?
    data.resetCounters.map(parseCounter) : [];
  if (counters.length === 0 || counters.length > 12 ||
      new Set(counters.map((counter) => counter.key)).size !== counters.length) {
    throw new WorkflowError(
      "failed-precondition",
      "The frozen maintenance classification reset matrix is invalid.",
      {reasonCode: "maintenance-reset-matrix-invalid"},
    );
  }
  const lane = boundedText(data.principalLaneKey, "principalLaneKey", 20);
  if (!["elec", "mech", "inst", "oprn", "emd", "red", "shared"].includes(lane)) {
    throw new WorkflowError("failed-precondition", "The maintenance owner lane is invalid.");
  }
  const assetTypeKeys = stringList(data.assetTypeKeys, "assetTypeKeys", 10, true);
  const assetClassIds = stringList(data.assetClassIds, "assetClassIds", 30, true);
  if (assetTypeKeys.length === 0 && assetClassIds.length === 0) {
    throw new WorkflowError(
      "failed-precondition",
      "The frozen maintenance classification has no asset scope.",
    );
  }
  return {
    schemaVersion: 1,
    definitionId: documentId(data.definitionId, "definitionId"),
    definitionVersion: positiveVersion(data.definitionVersion, "definitionVersion"),
    code: boundedText(data.code, "code", 48),
    title: boundedText(data.title, "title", 160),
    assetTypeKeys,
    assetClassIds,
    resetCounters: counters,
    principalLaneKey: lane as LaneKey,
  };
};

const metadataMap = (value: unknown): JsonMap => {
  if (typeof value !== "string" || value.trim().length === 0) return {};
  try {
    const parsed = JSON.parse(value) as unknown;
    if (parsed != null && typeof parsed === "object" && !Array.isArray(parsed)) {
      return parsed as JsonMap;
    }
  } catch (_) {
    // A legacy metadata value is preserved by classification writes below.
  }
  return {legacyMetadataJson: value};
};

export const frozenMaintenanceClassFromExecution = (
  execution: JsonMap,
): FrozenMaintenanceClass | null => {
  const metadata = metadataMap(execution.metadataJson);
  if (!Object.prototype.hasOwnProperty.call(metadata, "maintenanceClassification")) {
    return null;
  }
  return parseFrozenMaintenanceClass(metadata.maintenanceClassification);
};

export const metadataWithMaintenanceClassification = (
  currentMetadataJson: unknown,
  classification: FrozenMaintenanceClass,
  revision: number,
  classifiedBy: Actor,
  classifiedAt: string,
  reason: string,
): string => JSON.stringify({
  ...metadataMap(currentMetadataJson),
  maintenanceClassification: classification,
  maintenanceClassificationRevision: revision,
  maintenanceClassifiedByUid: classifiedBy.uid,
  maintenanceClassifiedByName: classifiedBy.name,
  maintenanceClassifiedAt: classifiedAt,
  maintenanceClassificationReason: reason,
});

export const maintenanceAssetIdentityFromExecution = (
  execution: JsonMap,
): MaintenanceAssetIdentity => {
  const assetTypeKey = boundedText(
    execution.assetType ?? execution.assetTypeKey,
    "execution.assetType",
    48,
  );
  const assetNumber = execution.assetNumber;
  const serialInnerCover = assetTypeKey === "innerCover" && assetNumber == null;
  if (!serialInnerCover &&
      (typeof assetNumber !== "number" || !Number.isSafeInteger(assetNumber) ||
       assetNumber < 1)) {
    throw new WorkflowError(
      "failed-precondition",
      "The execution asset number is invalid.",
      {reasonCode: "maintenance-completion-asset-invalid"},
    );
  }
  const assetClassId = optionalDocumentId(execution.assetClassId, "assetClassId");
  const assetInstanceId = optionalDocumentId(
    execution.assetInstanceId,
    "assetInstanceId",
  );
  if ((assetClassId == null) !== (assetInstanceId == null)) {
    throw new WorkflowError(
      "failed-precondition",
      "The execution asset registry identity is incomplete.",
      {reasonCode: "maintenance-completion-asset-identity-incomplete"},
    );
  }
  if (serialInnerCover && (assetClassId == null || assetInstanceId == null)) {
    throw new WorkflowError(
      "failed-precondition",
      "A serial-based Inner Cover requires its complete governed identity.",
      {reasonCode: "maintenance-completion-asset-identity-incomplete"},
    );
  }
  const assetIdentityKey = assetClassId != null ?
    `${assetClassId}:${assetInstanceId}` : `${assetTypeKey}:${assetNumber}`;
  return {
    assetIdentityKey,
    assetTypeKey,
    assetNumber: serialInnerCover ? null : assetNumber as number,
    assetClassId,
    assetInstanceId,
  };
};

export const assertMaintenanceClassApplies = (
  classification: FrozenMaintenanceClass,
  identity: MaintenanceAssetIdentity,
): void => {
  const matchesType = classification.assetTypeKeys.includes(identity.assetTypeKey);
  const matchesClass = identity.assetClassId != null &&
    classification.assetClassIds.includes(identity.assetClassId);
  if (!matchesType && !matchesClass) {
    throw new WorkflowError(
      "failed-precondition",
      "The maintenance class does not apply to this asset.",
      {
        reasonCode: "maintenance-class-asset-scope-mismatch",
        assetIdentityKey: identity.assetIdentityKey,
        maintenanceClassCode: classification.code,
      },
    );
  }
};

const stableId = (prefix: string, value: string): string =>
  `${prefix}_${createHash("sha256").update(value, "utf8").digest("hex").slice(0, 40)}`;

export const completionEventId = (
  sourceType: string,
  sourceId: string,
  revision: number,
): string => stableId("mce", `${sourceType}|${sourceId}|${revision}`);

export const completionSourcePath = (
  sourceType: string,
  sourceId: string,
): string => `maintenance_completion_sources/${stableId("mcs", `${sourceType}|${sourceId}`)}`;

export const dueStatePath = (
  assetIdentityKey: string,
  counterKey: string,
): string => `maintenance_due_states/${stableId("mds", `${assetIdentityKey}|${counterKey}`)}`;

const validIso = (value: unknown, field: string): string => {
  if (typeof value !== "string") {
    throw new WorkflowError("failed-precondition", `${field} is missing.`);
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new WorkflowError("failed-precondition", `${field} is invalid.`);
  }
  return parsed.toISOString();
};

const nextDueAt = (completedAt: string, thresholdDays: number | null): string | null => {
  if (thresholdDays == null) return null;
  const next = new Date(completedAt);
  next.setUTCDate(next.getUTCDate() + thresholdDays);
  return next.toISOString();
};

export const prepareMaintenanceCompletionWritePlan = async (args: {
  readonly tx: WorkflowTransaction;
  readonly execution: JsonMap;
  readonly executionId: string;
  readonly sourceType: string;
  readonly completedAt: string;
  readonly completedBy: Actor | {
    readonly uid: string | null;
    readonly name: string | null;
  };
  readonly recordedAt: string;
  readonly classification?: FrozenMaintenanceClass | null;
  readonly classificationRevision?: number;
}): Promise<MaintenanceCompletionWritePlan | null> => {
  const classification = args.classification ??
    frozenMaintenanceClassFromExecution(args.execution);
  if (classification == null) return null;
  const identity = maintenanceAssetIdentityFromExecution(args.execution);
  assertMaintenanceClassApplies(classification, identity);
  const completedAt = validIso(args.completedAt, "completedAt");
  const revision = args.classificationRevision ?? 1;
  if (!Number.isSafeInteger(revision) || revision < 1) {
    throw new WorkflowError("failed-precondition", "Classification revision is invalid.");
  }
  const eventId = completionEventId(args.sourceType, args.executionId, revision);
  const eventPath = `maintenance_completion_events/${eventId}`;
  const sourcePath = completionSourcePath(args.sourceType, args.executionId);
  const duePaths = classification.resetCounters.map((counter) =>
    dueStatePath(identity.assetIdentityKey, counter.key));
  const [event, source, ...dueSnapshots] = await Promise.all([
    args.tx.get(eventPath),
    args.tx.get(sourcePath),
    ...duePaths.map((path) => args.tx.get(path)),
  ]);
  if (event.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance completion evidence already exists without a matching replay receipt.",
      {reasonCode: "maintenance-completion-event-orphan", eventId},
    );
  }
  if (revision === 1 && source.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "A maintenance completion source projection already exists.",
      {reasonCode: "maintenance-completion-source-collision"},
    );
  }
  const resetCounterKeys = classification.resetCounters.map((counter) => counter.key);
  const assetDisplayName = typeof args.execution.assetInstanceName === "string" &&
    args.execution.assetInstanceName.trim().length > 0 ?
    args.execution.assetInstanceName.trim() : null;
  const common: JsonMap = {
    schemaVersion: 1,
    sourceType: args.sourceType,
    sourceId: args.executionId,
    sourceRevision: revision,
    assetIdentityKey: identity.assetIdentityKey,
    assetTypeKey: identity.assetTypeKey,
    assetNumber: identity.assetNumber,
    assetClassId: identity.assetClassId,
    assetInstanceId: identity.assetInstanceId,
    assetDisplayName,
    maintenanceClass: classification as unknown as JsonMap,
    maintenanceClassDefinitionId: classification.definitionId,
    maintenanceClassDefinitionVersion: classification.definitionVersion,
    maintenanceClassCode: classification.code,
    maintenanceClassTitle: classification.title,
    resetCounterKeys,
    completedAt,
    completedByUid: args.completedBy.uid,
    completedByName: args.completedBy.name,
    recordedAt: validIso(args.recordedAt, "recordedAt"),
  };
  const eventData: JsonMap = {eventId, ...common};
  const sourceData: JsonMap = {
    sourceProjectionId: sourcePath.split("/").at(-1)!,
    ...common,
    currentEventId: eventId,
  };
  const dueStates = classification.resetCounters.flatMap((counter, index) => {
    const current = dueSnapshots[index].data;
    const currentAtText = persistedInstantText(current?.lastCompletionAt);
    const currentAt = currentAtText == null ?
      Number.NaN : Date.parse(currentAtText);
    if (Number.isFinite(currentAt) && currentAt > Date.parse(completedAt)) return [];
    const path = duePaths[index];
    return [{
      path,
      data: {
        schemaVersion: 1,
        dueStateId: path.split("/").at(-1)!,
        assetIdentityKey: identity.assetIdentityKey,
        assetTypeKey: identity.assetTypeKey,
        assetNumber: identity.assetNumber,
        assetClassId: identity.assetClassId,
        assetInstanceId: identity.assetInstanceId,
        assetDisplayName,
        counterKey: counter.key,
        counterLabel: counter.label,
        thresholdDays: counter.thresholdDays,
        lastCompletionAt: completedAt,
        nextDueAt: nextDueAt(completedAt, counter.thresholdDays),
        lastCompletionEventId: eventId,
        lastCompletionSourceType: args.sourceType,
        lastCompletionSourceId: args.executionId,
        lastMaintenanceClassCode: classification.code,
        classificationPending: false,
        updatedAt: args.recordedAt,
      },
    }];
  });
  return {eventId, eventPath, eventData, sourcePath, sourceData, dueStates};
};

export const applyMaintenanceCompletionWritePlan = (
  tx: WorkflowTransaction,
  plan: MaintenanceCompletionWritePlan | null,
): void => {
  if (plan == null) return;
  tx.create(plan.eventPath, plan.eventData);
  tx.set(plan.sourcePath, plan.sourceData, true);
  for (const due of plan.dueStates) tx.set(due.path, due.data, true);
};
