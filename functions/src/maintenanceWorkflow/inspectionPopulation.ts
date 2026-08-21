import {WorkflowError} from "./errors";
import {JsonMap} from "./types";

export type InspectionTargetDisposition =
  | "pending"
  | "observed"
  | "deferred"
  | "unavailable"
  | "excludedWithReason"
  | "requiresReaudit";

export interface InspectionPopulationAsset {
  readonly assetNumber: number;
  readonly assetInstanceId: string;
  readonly assetInstanceVersion: number;
  readonly assetInstanceName: string;
}

export interface InspectionCampaignTarget {
  readonly schemaVersion: 1;
  readonly targetKey: string;
  readonly assetTypeKey: string;
  readonly assetClassId: string;
  readonly assetNumber: number;
  readonly assetInstanceId: string;
  readonly assetInstanceVersion: number;
  readonly assetInstanceName: string;
  readonly componentNodeId: string | null;
  readonly physicalPosition: string | null;
  readonly disposition: InspectionTargetDisposition;
  readonly dispositionReason: string | null;
  readonly dispositionAt: string;
  readonly dispositionByUid: string;
  readonly dispositionByName: string;
  readonly addedLater: boolean;
  readonly lastObservationId: string | null;
  readonly lastObservedAt: string | null;
}

const dispositions = new Set<InspectionTargetDisposition>([
  "pending",
  "observed",
  "deferred",
  "unavailable",
  "excludedWithReason",
  "requiresReaudit",
]);

const requiredString = (value: unknown, field: string): string => {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new WorkflowError(
      "failed-precondition",
      `Inspection target ${field} is missing or malformed.`,
      {reasonCode: "inspection-target-population-malformed", field},
    );
  }
  return value.trim();
};

const optionalString = (value: unknown, field: string): string | null => {
  if (value == null) return null;
  return requiredString(value, field);
};

export const inspectionTargetKey = (args: {
  readonly assetClassId: string;
  readonly assetInstanceId: string;
  readonly componentNodeId: string | null;
  readonly physicalPosition: string | null;
}): string => `${args.assetClassId}:${args.assetInstanceId}` +
  `|${args.componentNodeId ?? "asset"}|${args.physicalPosition ?? "-"}`;

export const buildInspectionTargetPopulation = (args: {
  readonly assetTypeKey: string;
  readonly assetClassId: string;
  readonly assets: readonly InspectionPopulationAsset[];
  readonly componentNodeIds: readonly string[];
  readonly physicalPositions: readonly string[];
  readonly at: string;
  readonly actorUid: string;
  readonly actorName: string;
  readonly addedLater: boolean;
}): InspectionCampaignTarget[] => {
  const components = args.componentNodeIds.length === 0 ? [null] : args.componentNodeIds;
  const positions = args.physicalPositions.length === 0 ? [null] : args.physicalPositions;
  const targets: InspectionCampaignTarget[] = [];
  for (const asset of args.assets) {
    for (const componentNodeId of components) {
      for (const physicalPosition of positions) {
        const targetKey = inspectionTargetKey({
          assetClassId: args.assetClassId,
          assetInstanceId: asset.assetInstanceId,
          componentNodeId,
          physicalPosition,
        });
        targets.push({
          schemaVersion: 1,
          targetKey,
          assetTypeKey: args.assetTypeKey,
          assetClassId: args.assetClassId,
          assetNumber: asset.assetNumber,
          assetInstanceId: asset.assetInstanceId,
          assetInstanceVersion: asset.assetInstanceVersion,
          assetInstanceName: asset.assetInstanceName,
          componentNodeId,
          physicalPosition,
          disposition: "pending",
          dispositionReason: null,
          dispositionAt: args.at,
          dispositionByUid: args.actorUid,
          dispositionByName: args.actorName,
          addedLater: args.addedLater,
          lastObservationId: null,
          lastObservedAt: null,
        });
      }
    }
  }
  const keys = targets.map((target) => target.targetKey);
  if (new Set(keys).size !== keys.length) {
    throw new WorkflowError(
      "invalid-argument",
      "Inspection target population contains duplicate targets.",
      {reasonCode: "inspection-target-population-duplicate"},
    );
  }
  return targets;
};

export const parseInspectionTargetPopulation = (
  value: unknown,
): InspectionCampaignTarget[] => {
  if (!Array.isArray(value) || value.length === 0 || value.length > 500) {
    throw new WorkflowError(
      "failed-precondition",
      "Inspection campaign target population is missing or outside its governed limit.",
      {reasonCode: "inspection-target-population-malformed"},
    );
  }
  const targets = value.map((item, index): InspectionCampaignTarget => {
    if (item == null || typeof item !== "object" || Array.isArray(item)) {
      throw new WorkflowError(
        "failed-precondition",
        "Inspection campaign contains a malformed target.",
        {reasonCode: "inspection-target-population-malformed", index},
      );
    }
    const data = item as JsonMap;
    const disposition = requiredString(data.disposition, "disposition") as
      InspectionTargetDisposition;
    if (data.schemaVersion !== 1 || !dispositions.has(disposition) ||
        typeof data.assetNumber !== "number" ||
        !Number.isSafeInteger(data.assetNumber) || data.assetNumber < 1 ||
        typeof data.assetInstanceVersion !== "number" ||
        !Number.isSafeInteger(data.assetInstanceVersion) ||
        data.assetInstanceVersion < 1 || typeof data.addedLater !== "boolean") {
      throw new WorkflowError(
        "failed-precondition",
        "Inspection campaign contains a malformed target.",
        {reasonCode: "inspection-target-population-malformed", index},
      );
    }
    const target: InspectionCampaignTarget = {
      schemaVersion: 1,
      targetKey: requiredString(data.targetKey, "targetKey"),
      assetTypeKey: requiredString(data.assetTypeKey, "assetTypeKey"),
      assetClassId: requiredString(data.assetClassId, "assetClassId"),
      assetNumber: data.assetNumber,
      assetInstanceId: requiredString(data.assetInstanceId, "assetInstanceId"),
      assetInstanceVersion: data.assetInstanceVersion,
      assetInstanceName: requiredString(data.assetInstanceName, "assetInstanceName"),
      componentNodeId: optionalString(data.componentNodeId, "componentNodeId"),
      physicalPosition: optionalString(data.physicalPosition, "physicalPosition"),
      disposition,
      dispositionReason: optionalString(data.dispositionReason, "dispositionReason"),
      dispositionAt: requiredString(data.dispositionAt, "dispositionAt"),
      dispositionByUid: requiredString(data.dispositionByUid, "dispositionByUid"),
      dispositionByName: requiredString(data.dispositionByName, "dispositionByName"),
      addedLater: data.addedLater,
      lastObservationId: optionalString(data.lastObservationId, "lastObservationId"),
      lastObservedAt: optionalString(data.lastObservedAt, "lastObservedAt"),
    };
    if (target.targetKey !== inspectionTargetKey(target) ||
        (target.disposition === "pending" && target.dispositionReason != null) ||
        (target.disposition === "observed" &&
         (target.lastObservationId == null || target.lastObservedAt == null)) ||
        (!["pending", "observed"].includes(target.disposition) &&
         target.dispositionReason == null)) {
      throw new WorkflowError(
        "failed-precondition",
        "Inspection campaign target disposition is inconsistent.",
        {reasonCode: "inspection-target-population-inconsistent", targetKey: target.targetKey},
      );
    }
    return target;
  });
  const keys = targets.map((target) => target.targetKey);
  if (new Set(keys).size !== keys.length) {
    throw new WorkflowError(
      "failed-precondition",
      "Inspection campaign target identities are duplicated.",
      {reasonCode: "inspection-target-population-duplicate"},
    );
  }
  return targets;
};

export const inspectionTargetPopulationJson = (
  targets: readonly InspectionCampaignTarget[],
): readonly JsonMap[] => targets.map((target) => ({...target}));

export const markInspectionTargetObserved = (args: {
  readonly targets: readonly InspectionCampaignTarget[];
  readonly targetKey: string;
  readonly observationId: string;
  readonly observedAt: string;
  readonly actorUid: string;
  readonly actorName: string;
}): InspectionCampaignTarget[] => {
  let matched = false;
  const updated = args.targets.map((target) => {
    if (target.targetKey !== args.targetKey) return target;
    matched = true;
    if (target.disposition === "excludedWithReason" ||
        target.disposition === "unavailable") {
      throw new WorkflowError(
        "failed-precondition",
        "Reset the target to pending before recording evidence for it.",
        {reasonCode: "inspection-target-disposition-blocks-observation", targetKey: target.targetKey},
      );
    }
    return {
      ...target,
      disposition: "observed" as const,
      dispositionReason: null,
      dispositionAt: args.observedAt,
      dispositionByUid: args.actorUid,
      dispositionByName: args.actorName,
      lastObservationId: args.observationId,
      lastObservedAt: args.observedAt,
    };
  });
  if (!matched) {
    throw new WorkflowError(
      "failed-precondition",
      "Observation target is not part of the governed campaign population.",
      {reasonCode: "inspection-target-not-in-population", targetKey: args.targetKey},
    );
  }
  return updated;
};

export const setInspectionTargetDisposition = (args: {
  readonly targets: readonly InspectionCampaignTarget[];
  readonly targetKey: string;
  readonly disposition: Exclude<InspectionTargetDisposition, "observed">;
  readonly reason: string | null;
  readonly at: string;
  readonly actorUid: string;
  readonly actorName: string;
}): InspectionCampaignTarget[] => {
  let matched = false;
  const updated = args.targets.map((target) => {
    if (target.targetKey !== args.targetKey) return target;
    matched = true;
    return {
      ...target,
      disposition: args.disposition,
      dispositionReason: args.disposition === "pending" ? null : args.reason,
      dispositionAt: args.at,
      dispositionByUid: args.actorUid,
      dispositionByName: args.actorName,
    };
  });
  if (!matched) {
    throw new WorkflowError(
      "not-found",
      "Inspection campaign target was not found.",
      {reasonCode: "inspection-target-not-found", targetKey: args.targetKey},
    );
  }
  return updated;
};

export const inspectionPopulationCounts = (
  targets: readonly InspectionCampaignTarget[],
): Readonly<Record<InspectionTargetDisposition, number>> => {
  const result: Record<InspectionTargetDisposition, number> = {
    pending: 0,
    observed: 0,
    deferred: 0,
    unavailable: 0,
    excludedWithReason: 0,
    requiresReaudit: 0,
  };
  for (const target of targets) result[target.disposition] += 1;
  return result;
};

export const inspectionTargetDispositionValues = dispositions;
