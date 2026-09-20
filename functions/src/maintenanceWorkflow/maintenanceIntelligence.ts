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

/**
 * Template-created executions historically carried the frozen class without
 * an explicit revision marker. Treat that established shape as revision one,
 * while preserving later reviewed corrections as their recorded revision.
 */
export const maintenanceClassificationRevisionFromExecution = (
  execution: JsonMap,
): number => {
  const metadata = metadataMap(execution.metadataJson);
  const value = metadata.maintenanceClassificationRevision;
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 1 ?
    value : 1;
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

export interface MaintenanceCompletionEvidence {
  readonly completedAt: string;
  readonly eventId: string | null;
  readonly sourceType: string | null;
  readonly sourceId: string | null;
  readonly sourceRevision: number;
}

const evidenceIdentity = (value: MaintenanceCompletionEvidence): string =>
  value.eventId ?? `${value.sourceType ?? ""}|${value.sourceId ?? ""}|${value.sourceRevision}`;

/**
 * Returns a positive value when `left` is the canonical winner. Physical time
 * is primary. A correction of the same source wins by that source's revision;
 * unrelated sources at the same instant use their stable event identity, so
 * arrival order cannot change the result.
 */
export const compareMaintenanceCompletionEvidence = (
  left: MaintenanceCompletionEvidence,
  right: MaintenanceCompletionEvidence,
): number => {
  const leftAt = Date.parse(left.completedAt);
  const rightAt = Date.parse(right.completedAt);
  if (leftAt !== rightAt) return leftAt - rightAt;
  if (left.sourceType === right.sourceType && left.sourceId === right.sourceId &&
      left.sourceRevision !== right.sourceRevision) {
    return left.sourceRevision - right.sourceRevision;
  }
  // Lexicographically smaller stable identities win. This is deliberately
  // independent of transaction arrival order and unrelated source revisions.
  return evidenceIdentity(right).localeCompare(evidenceIdentity(left));
};

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

export const dueProjectionFromSource = (
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
      return source.data.cadenceApplicability !== "historicalOnly" &&
        source.data.cadenceApplicability !== "withdrawn" &&
        source.data.assetIdentityKey === fallback.assetIdentityKey &&
        Array.isArray(source.data.resetCounterKeys) &&
        (source.data.resetCounterKeys as unknown[]).includes(counterKey) &&
        completedAt != null ? [{...source, completedAt}] : [];
    })
    .sort((left, right) => compareMaintenanceCompletionEvidence(
      {
        completedAt: right.completedAt,
        eventId: typeof right.data.currentEventId === "string" ? right.data.currentEventId : null,
        sourceType: typeof right.data.sourceType === "string" ? right.data.sourceType : null,
        sourceId: typeof right.data.sourceId === "string" ? right.data.sourceId : null,
        sourceRevision: typeof right.data.sourceRevision === "number" ? right.data.sourceRevision : 0,
      },
      {
        completedAt: left.completedAt,
        eventId: typeof left.data.currentEventId === "string" ? left.data.currentEventId : null,
        sourceType: typeof left.data.sourceType === "string" ? left.data.sourceType : null,
        sourceId: typeof left.data.sourceId === "string" ? left.data.sourceId : null,
        sourceRevision: typeof left.data.sourceRevision === "number" ? left.data.sourceRevision : 0,
      },
    ));
  // A legacy position and a registered subject may denote the same object,
  // but that cannot be inferred safely after number reuse. Hold only the
  // affected counter until reviewed identity evidence resolves the alias.
  const potentialAliases = sources.filter(({data}) =>
    data.cadenceApplicability !== "historicalOnly" && data.cadenceApplicability !== "withdrawn" &&
    data.assetTypeKey === fallback.assetTypeKey && data.assetNumber === fallback.assetNumber &&
    Array.isArray(data.resetCounterKeys) && data.resetCounterKeys.includes(counterKey));
  const identityReviewRequired = fallback.assetNumber != null &&
    new Set(potentialAliases.map(({data}) => data.assetIdentityKey)).size > 1 &&
    potentialAliases.some(({data}) => data.assetClassId == null && data.assetInstanceId == null);
  const latestCandidate = candidates[0];
  const latest = latestCandidate?.data;
  if (latest == null || latestCandidate == null || identityReviewRequired) {
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
      reviewReason: identityReviewRequired ? "legacy-identity-review-required" : "no-applicable-completion",
      conflictingCompletionEventIds: [],
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
  // The owner requires review when same-plant-day evidence implies different
  // deadlines. Stable event ordering is for presentation only, never precedence.
  const plantDay = (value: string): string =>
    new Date(Date.parse(value) + 330 * 60_000).toISOString().slice(0, 10);
  const sameDay = candidates.filter((candidate) =>
    plantDay(candidate.completedAt) === plantDay(completedAt));
  const dueDays = new Set(sameDay.map((candidate) => {
    const frozen = parseFrozenMaintenanceClass(candidate.data.maintenanceClass);
    const reset = frozen.resetCounters.find((item) => item.key === counterKey);
    if (reset == null) throw new WorkflowError("failed-precondition", "Counter evidence is inconsistent.");
    return reset.thresholdDays == null ? "unbounded" :
      plantDay(new Date(Date.parse(candidate.completedAt) + reset.thresholdDays * 86_400_000).toISOString());
  }));
  const conflicting = dueDays.size > 1;
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
    nextDueAt: conflicting ? null : nextDue,
    lastCompletionEventId: latest.currentEventId,
    lastCompletionSourceType: latest.sourceType,
    lastCompletionSourceId: latest.sourceId,
    lastMaintenanceClassCode: latest.maintenanceClassCode,
    classificationPending: conflicting,
    reviewReason: conflicting ? "conflicting-same-day-evidence" : null,
    conflictingCompletionEventIds: conflicting ?
      sameDay.map((candidate) => String(candidate.data.currentEventId)).sort() : [],
    updatedAt: now,
  };
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
  readonly cadenceApplicability?: "operational" | "historicalOnly";
  readonly datePrecision?: "date" | "instant";
  readonly interpretedBy?: Actor;
}): Promise<MaintenanceCompletionWritePlan | null> => {
  const classification = args.classification ??
    frozenMaintenanceClassFromExecution(args.execution);
  if (classification == null) return null;
  const identity = maintenanceAssetIdentityFromExecution(args.execution);
  assertMaintenanceClassApplies(classification, identity);
  const completedAt = validIso(args.completedAt, "completedAt");
  const revision = args.classificationRevision ??
    maintenanceClassificationRevisionFromExecution(args.execution);
  if (!Number.isSafeInteger(revision) || revision < 1) {
    throw new WorkflowError("failed-precondition", "Classification revision is invalid.");
  }
  const eventId = completionEventId(args.sourceType, args.executionId, revision);
  const eventPath = `maintenance_completion_events/${eventId}`;
  const sourcePath = completionSourcePath(args.sourceType, args.executionId);
  const duePaths = classification.resetCounters.map((counter) =>
    dueStatePath(identity.assetIdentityKey, counter.key));
  const [event, source] = await Promise.all([
    args.tx.get(eventPath),
    args.tx.get(sourcePath),
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
    cadenceApplicability: source.data?.cadenceApplicability ?? args.cadenceApplicability ?? "operational",
    datePrecision: source.data?.datePrecision ?? args.datePrecision ?? "instant",
    plantTimezone: "Asia/Kolkata",
    interpretedByUid: args.interpretedBy?.uid ?? null,
    interpretedByName: args.interpretedBy?.name ?? null,
  };
  const eventData: JsonMap = {eventId, ...common};
  const sourceData: JsonMap = {
    sourceProjectionId: sourcePath.split("/").at(-1)!,
    ...common,
    currentEventId: eventId,
  };
  const existingSources = (await args.tx.query("maintenance_completion_sources",
    identity.assetNumber == null ? [
      {field: "assetIdentityKey", op: "==", value: identity.assetIdentityKey},
    ] : [
      {field: "assetTypeKey", op: "==", value: identity.assetTypeKey},
      {field: "assetNumber", op: "==", value: identity.assetNumber},
    ])).filter((row) => row.data != null).map((row) => row.data!);
  const sources = existingSources.filter((candidate) =>
    !(candidate.sourceType === args.sourceType && candidate.sourceId === args.executionId))
    .map((data) => ({path: "", data}));
  sources.push({path: sourcePath, data: sourceData});
  const dueStates = sourceData.cadenceApplicability === "historicalOnly" ? [] :
    classification.resetCounters.map((counter, index) => ({
      path: duePaths[index],
      data: dueProjectionFromSource(duePaths[index], counter.key, sources, args.recordedAt, {
        ...identity, assetDisplayName, counterLabel: counter.label,
        thresholdDays: counter.thresholdDays,
      }),
    }));
  // Qualify already-visible alias counters in the same transaction as the
  // new record, so the older track cannot continue to look authoritative.
  if (sourceData.cadenceApplicability !== "historicalOnly") {
    for (const candidate of existingSources) {
      if (candidate.assetIdentityKey === identity.assetIdentityKey ||
          candidate.assetNumber !== identity.assetNumber ||
          !(candidate.assetClassId == null || identity.assetClassId == null)) continue;
      const frozen = parseFrozenMaintenanceClass(candidate.maintenanceClass);
      for (const counter of frozen.resetCounters) {
        const path = dueStatePath(String(candidate.assetIdentityKey), counter.key);
        if (dueStates.some((row) => row.path === path)) continue;
        const data = dueProjectionFromSource(path, counter.key, sources, args.recordedAt, {
          assetIdentityKey: String(candidate.assetIdentityKey), assetTypeKey: String(candidate.assetTypeKey),
          assetNumber: candidate.assetNumber as number,
          assetClassId: candidate.assetClassId as string | null,
          assetInstanceId: candidate.assetInstanceId as string | null,
          assetDisplayName: candidate.assetDisplayName as string | null,
          counterLabel: counter.label, thresholdDays: counter.thresholdDays,
        });
        if (data.reviewReason === "legacy-identity-review-required") dueStates.push({path, data});
      }
    }
  }
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
