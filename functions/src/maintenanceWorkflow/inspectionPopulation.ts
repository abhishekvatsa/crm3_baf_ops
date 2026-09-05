import {WorkflowError} from "./errors";
import {WorkflowTransaction} from "./store";
import {JsonMap} from "./types";
import {persistedInstantText} from "./utils";

export type InspectionTargetDisposition =
  | "pending"
  | "observed"
  | "deferred"
  | "unavailable"
  | "excludedWithReason"
  | "requiresReaudit";

export type InspectionPopulationMode =
  | "assetInstances"
  | "installedInnerCoversByBase";

export interface InstalledInnerCoverTargetContext {
  readonly hostAssetClassId: string;
  readonly hostAssetInstanceId: string;
  readonly hostAssetInstanceVersion: number;
  readonly hostAssetNumber: number;
  readonly hostAssetInstanceName: string;
  readonly subjectSerialNumber: string;
  readonly linkageId: string;
  readonly linkageVersion: number;
  readonly linkedAt: string;
}

export interface InspectionPopulationAsset {
  readonly assetNumber: number;
  readonly assetInstanceId: string;
  readonly assetInstanceVersion: number;
  readonly assetInstanceName: string;
  readonly installedInnerCoverContext?: InstalledInnerCoverTargetContext;
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
  readonly hostAssetClassId: string | null;
  readonly hostAssetInstanceId: string | null;
  readonly hostAssetInstanceVersion: number | null;
  readonly hostAssetNumber: number | null;
  readonly hostAssetInstanceName: string | null;
  readonly subjectSerialNumber: string | null;
  readonly linkageId: string | null;
  readonly linkageVersion: number | null;
  readonly linkedAt: string | null;
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

const positiveInteger = (value: unknown, field: string): number => {
  if (!Number.isSafeInteger(value) || (value as number) < 1) {
    throw new WorkflowError(
      "failed-precondition",
      `Inspection target ${field} is missing or malformed.`,
      {reasonCode: "inspection-target-population-malformed", field},
    );
  }
  return value as number;
};

export const resolveInspectionPopulationAssets = async (args: {
  readonly tx: WorkflowTransaction;
  readonly populationMode: InspectionPopulationMode;
  readonly assetTypeKey: string;
  readonly assetClassId: string;
  readonly hostAssetClassId: string | null;
  readonly targetAssetNumbers: readonly number[];
}): Promise<InspectionPopulationAsset[]> => {
  const lookupClassId = args.populationMode === "assetInstances" ?
    args.assetClassId : args.hostAssetClassId;
  if (lookupClassId == null ||
      (args.populationMode === "installedInnerCoversByBase" &&
       args.assetTypeKey !== "innerCover")) {
    throw new WorkflowError(
      "invalid-argument",
      "Installed Inner Cover campaigns require an exact Base host class.",
      {reasonCode: "inspection-inner-cover-host-class-required"},
    );
  }
  const rows = await args.tx.query("asset_instances", [
    {field: "assetClassId", op: "==", value: lookupClassId},
  ]);
  const byNumber = new Map<number, (typeof rows)[number]>();
  for (const row of rows) {
    if (row.data?.status !== "active" ||
        !Number.isSafeInteger(row.data.assetNumber) ||
        !args.targetAssetNumbers.includes(row.data.assetNumber as number)) continue;
    const number = row.data.assetNumber as number;
    const pathIdentity = row.path.split("/").at(-1);
    if (pathIdentity == null ||
        requiredString(row.data.assetInstanceId, "assetInstanceId") !== pathIdentity) {
      throw new WorkflowError(
        "failed-precondition",
        "A governed inspection asset has an inconsistent registry identity.",
        {reasonCode: "inspection-campaign-asset-identity-malformed", assetNumber: number},
      );
    }
    if (byNumber.has(number)) {
      throw new WorkflowError(
        "failed-precondition",
        "The governed asset class contains duplicate active asset numbers.",
        {reasonCode: "inspection-campaign-asset-number-ambiguous", assetNumber: number},
      );
    }
    byNumber.set(number, row);
  }
  const missing = args.targetAssetNumbers.filter((number) => !byNumber.has(number));
  if (missing.length > 0) {
    throw new WorkflowError(
      "failed-precondition",
      "One or more inspection targets are absent or inactive in the governed asset registry.",
      {reasonCode: "inspection-campaign-assets-missing", missingAssetNumbers: missing},
    );
  }
  if (args.populationMode === "assetInstances") {
    return args.targetAssetNumbers.map((assetNumber) => {
      const data = byNumber.get(assetNumber)!.data!;
      return {
        assetNumber,
        assetInstanceId: requiredString(data.assetInstanceId, "assetInstanceId"),
        assetInstanceVersion: positiveInteger(data.version, "assetInstanceVersion"),
        assetInstanceName: requiredString(data.name, "assetInstanceName"),
      };
    });
  }

  const assignments = await Promise.all(args.targetAssetNumbers.map((number) => {
    const host = byNumber.get(number)!;
    return args.tx.get(`base_inner_cover_assignments/${host.data!.assetInstanceId}`);
  }));
  const assignmentByBaseId = new Map(assignments.map((row) => [
    row.path.split("/").at(-1)!, row,
  ]));
  const identities = args.targetAssetNumbers.map((number) => {
    const host = byNumber.get(number)!;
    const hostData = host.data!;
    const hostId = requiredString(hostData.assetInstanceId, "hostAssetInstanceId");
    const assignment = assignmentByBaseId.get(hostId);
    if (!assignment?.exists || assignment.data == null) {
      throw new WorkflowError(
        "failed-precondition",
        `Base ${number} has no currently installed Inner Cover.`,
        {reasonCode: "inspection-inner-cover-assignment-missing", baseAssetNumber: number},
      );
    }
    const data = assignment.data;
    const innerCoverId = requiredString(data.innerCoverId, "innerCoverId");
    const linkageId = requiredString(data.linkageId, "linkageId");
    if (data.baseAssetInstanceId !== hostId ||
        data.baseAssetClassId !== lookupClassId ||
        data.baseAssetNumber !== number) {
      throw new WorkflowError(
        "failed-precondition",
        "The current Base and Inner Cover assignment projection is inconsistent.",
        {reasonCode: "inspection-inner-cover-assignment-malformed", baseAssetNumber: number},
      );
    }
    return {number, hostData, hostId, data, innerCoverId, linkageId};
  });
  const [profiles, linkages] = await Promise.all([
    Promise.all(identities.map((item) =>
      args.tx.get(`inner_cover_profiles/${item.innerCoverId}`))),
    Promise.all(identities.map((item) =>
      args.tx.get(`inner_cover_linkages/${item.linkageId}`))),
  ]);
  return identities.map((identity, index) => {
    const profile = profiles[index];
    const linkage = linkages[index];
    if (!profile.exists || profile.data == null ||
        !linkage.exists || linkage.data == null) {
      throw new WorkflowError(
        "failed-precondition",
        "The installed Inner Cover identity or linkage evidence is missing.",
        {reasonCode: "inspection-inner-cover-evidence-missing", baseAssetNumber: identity.number},
      );
    }
    const serial = requiredString(profile.data.serialNumber, "subjectSerialNumber");
    const linkedAt = persistedInstantText(identity.data.linkedAt);
    const linkageInstalledAt = persistedInstantText(linkage.data.installedAt);
    if (profile.data.assetClassId !== args.assetClassId ||
        profile.data.innerCoverId !== identity.innerCoverId ||
        profile.data.lifecycleState !== "installed" ||
        profile.data.currentBaseAssetInstanceId !== identity.hostId ||
        profile.data.currentBaseAssetNumber !== identity.number ||
        profile.data.currentLinkageId !== identity.linkageId ||
        identity.data.innerCoverSerialNumber !== serial ||
        linkage.data.linkageId !== identity.linkageId ||
        linkage.data.active !== true ||
        linkage.data.baseAssetInstanceId !== identity.hostId ||
        linkage.data.innerCoverId !== identity.innerCoverId ||
        linkage.data.innerCoverSerialNumber !== serial || linkedAt == null ||
        linkageInstalledAt !== linkedAt) {
      throw new WorkflowError(
        "failed-precondition",
        "The installed Inner Cover identity no longer matches its governed Base linkage.",
        {reasonCode: "inspection-inner-cover-context-inconsistent", baseAssetNumber: identity.number},
      );
    }
    return {
      assetNumber: identity.number,
      assetInstanceId: identity.innerCoverId,
      assetInstanceVersion: positiveInteger(profile.data.version, "assetInstanceVersion"),
      assetInstanceName: `Inner Cover ${serial}`,
      installedInnerCoverContext: {
        hostAssetClassId: lookupClassId,
        hostAssetInstanceId: identity.hostId,
        hostAssetInstanceVersion: positiveInteger(
          identity.hostData.version,
          "hostAssetInstanceVersion",
        ),
        hostAssetNumber: identity.number,
        hostAssetInstanceName: requiredString(
          identity.hostData.name,
          "hostAssetInstanceName",
        ),
        subjectSerialNumber: serial,
        linkageId: identity.linkageId,
        linkageVersion: positiveInteger(linkage.data.version, "linkageVersion"),
        linkedAt,
      },
    };
  });
};

export const inspectionTargetKey = (args: {
  readonly assetClassId: string;
  readonly assetInstanceId: string;
  readonly componentNodeId: string | null;
  readonly physicalPosition: string | null;
  readonly linkageId?: string | null;
}): string => `${args.assetClassId}:${args.assetInstanceId}` +
  `|${args.componentNodeId ?? "asset"}|${args.physicalPosition ?? "-"}` +
  (args.linkageId == null ? "" : `|link:${args.linkageId}`);

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
          linkageId: asset.installedInnerCoverContext?.linkageId,
        });
        const context = asset.installedInnerCoverContext;
        targets.push({
          schemaVersion: 1,
          targetKey,
          assetTypeKey: args.assetTypeKey,
          assetClassId: args.assetClassId,
          assetNumber: asset.assetNumber,
          assetInstanceId: asset.assetInstanceId,
          assetInstanceVersion: asset.assetInstanceVersion,
          assetInstanceName: asset.assetInstanceName,
          hostAssetClassId: context?.hostAssetClassId ?? null,
          hostAssetInstanceId: context?.hostAssetInstanceId ?? null,
          hostAssetInstanceVersion: context?.hostAssetInstanceVersion ?? null,
          hostAssetNumber: context?.hostAssetNumber ?? null,
          hostAssetInstanceName: context?.hostAssetInstanceName ?? null,
          subjectSerialNumber: context?.subjectSerialNumber ?? null,
          linkageId: context?.linkageId ?? null,
          linkageVersion: context?.linkageVersion ?? null,
          linkedAt: context?.linkedAt ?? null,
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
      hostAssetClassId: optionalString(data.hostAssetClassId, "hostAssetClassId"),
      hostAssetInstanceId: optionalString(data.hostAssetInstanceId, "hostAssetInstanceId"),
      hostAssetInstanceVersion: data.hostAssetInstanceVersion == null ? null :
        data.hostAssetInstanceVersion as number,
      hostAssetNumber: data.hostAssetNumber == null ? null : data.hostAssetNumber as number,
      hostAssetInstanceName: optionalString(data.hostAssetInstanceName, "hostAssetInstanceName"),
      subjectSerialNumber: optionalString(data.subjectSerialNumber, "subjectSerialNumber"),
      linkageId: optionalString(data.linkageId, "linkageId"),
      linkageVersion: data.linkageVersion == null ? null : data.linkageVersion as number,
      linkedAt: optionalString(data.linkedAt, "linkedAt"),
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
    const contextValues = [
      target.hostAssetClassId,
      target.hostAssetInstanceId,
      target.hostAssetInstanceVersion,
      target.hostAssetNumber,
      target.hostAssetInstanceName,
      target.subjectSerialNumber,
      target.linkageId,
      target.linkageVersion,
      target.linkedAt,
    ];
    const hasAnyContext = contextValues.some((item) => item != null);
    const hasCompleteContext = contextValues.every((item) => item != null);
    const invalidContextNumbers = hasCompleteContext &&
      (!Number.isSafeInteger(target.hostAssetInstanceVersion) ||
       (target.hostAssetInstanceVersion as number) < 1 ||
       !Number.isSafeInteger(target.hostAssetNumber) ||
       (target.hostAssetNumber as number) < 1 ||
       !Number.isSafeInteger(target.linkageVersion) ||
       (target.linkageVersion as number) < 1);
    if (target.targetKey !== inspectionTargetKey(target) ||
        (hasAnyContext && !hasCompleteContext) || invalidContextNumbers ||
        (hasCompleteContext &&
         (target.assetTypeKey !== "innerCover" ||
          target.assetNumber !== target.hostAssetNumber)) ||
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
