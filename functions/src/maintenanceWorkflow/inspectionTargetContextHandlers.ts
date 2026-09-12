import {WorkflowError} from "./errors";
import {CommandHandler} from "./handlerTypes";
import {WorkflowTransaction} from "./store";
import {JsonMap} from "./types";
import {cleanText, intValue, iso, stableJson} from "./utils";
import {
  buildInspectionTargetPopulation, InspectionCampaignTarget,
  inspectionContextIdentity, inspectionTargetPopulationJson, parseInspectionTargetPopulation,
  resolveInspectionPopulationAssets, sameInspectionPhysicalTarget,
} from "./inspectionPopulation";

export async function requireInspectionContextReview(
  tx: WorkflowTransaction, campaignId: string, target: InspectionCampaignTarget,
): Promise<InspectionCampaignTarget> {
  const review = target.contextReview;
  if (review == null) return target;
  const audit = await tx.get(`inspection_target_audits/${review.auditId}`);
  if (!audit.exists || audit.data == null || audit.data.schemaVersion !== 1 ||
      audit.data.auditId !== review.auditId || audit.data.campaignId !== campaignId ||
      audit.data.targetKey !== target.targetKey || audit.data.operation !== "revalidate-context" ||
      audit.data.performedByUid !== review.reviewedByUid ||
      audit.data.performedByName !== review.reviewedByName ||
      audit.data.performedAt !== review.reviewedAt || audit.data.reason !== review.reason ||
      audit.data.afterJson !== stableJson(review as unknown as JsonMap)) {
    throw new WorkflowError("failed-precondition", "The reviewed inspection context lacks its original audit evidence.",
      {reasonCode: "inspection-context-review-evidence-missing"});
  }
  // Only the physical context advances. Coverage and latest-reading pointers
  // belong to the original logical target and must survive every review.
  return {...target, ...review.context, targetKey: target.targetKey,
    disposition: target.disposition, dispositionReason: target.dispositionReason,
    dispositionAt: target.dispositionAt, dispositionByUid: target.dispositionByUid,
    dispositionByName: target.dispositionByName, addedLater: target.addedLater,
    lastObservationId: target.lastObservationId, lastObservedAt: target.lastObservedAt,
    contextReview: target.contextReview};
}

/** Explicit same-subject successor. The original population, key, definition,
 * measurements and re-audit baseline remain intact. No current occupant is
 * substituted for the physical serial originally selected by the campaign.
 */
export const revalidateInspectionTargetContext: CommandHandler = async ({tx, command, context}) => {
  if (Object.keys(command.payload).sort().join(",") !==
      ["targetKey", "expectedContextRevision", "reviewedContext", "reason", "reviewerUid"].sort().join(",")) {
    throw new WorkflowError("invalid-argument", "Target context review has unsupported or missing fields.");
  }
  if (command.payload.reviewerUid !== context.actor.uid) {
    throw new WorkflowError("permission-denied", "Only the original approved reviewer may submit this target review.",
      {reasonCode: "inspection-context-review-actor-changed"});
  }
  const targetKey = cleanText(command.payload.targetKey, "targetKey");
  const reason = cleanText(command.payload.reason, "reason");
  const expectedContextRevision = intValue(command.payload.expectedContextRevision, "expectedContextRevision");
  if (reason.length > 1000 || targetKey.length > 1000) {
    throw new WorkflowError("invalid-argument", "Target context review text is too long.");
  }
  const campaignId = command.aggregateId;
  const auditPath = `inspection_target_audits/${command.commandId}`;
  const [campaign, audit] = await Promise.all([
    tx.get(`inspection_campaigns/${campaignId}`), tx.get(auditPath),
  ]);
  if (!campaign.exists || campaign.data == null || campaign.data.version !== command.expectedVersion) {
    throw new WorkflowError("aborted", "Inspection campaign is missing or changed.");
  }
  if (!["open", "paused"].includes(String(campaign.data.status)) || audit.exists) {
    throw new WorkflowError("failed-precondition", "Reopen the campaign before reviewing its target context.");
  }
  const targets = parseInspectionTargetPopulation(campaign.data.targetPopulation);
  const target = targets.find((item) => item.targetKey === targetKey);
  if (target == null || (target.contextReview?.revision ?? 0) !== expectedContextRevision) {
    throw new WorkflowError("aborted", "The selected inspection target context changed. Review it again.");
  }
  const previous = await requireInspectionContextReview(tx, campaignId, target);
  const definition = campaign.data.definition as JsonMap | undefined;
  if (definition == null || typeof definition !== "object" || Array.isArray(definition) ||
      definition.schemaVersion !== 1 ||
      (!Array.isArray(definition.assetClassIds) || !Array.isArray(definition.assetTypeKeys)) ||
      !(definition.assetClassIds.length > 0 ? definition.assetClassIds.includes(target.assetClassId) :
        definition.assetTypeKeys.includes(target.assetTypeKey)) ||
      !Array.isArray(definition.componentNodeIds) ||
      (target.componentNodeId != null && !definition.componentNodeIds.includes(target.componentNodeId))) {
    throw new WorkflowError("failed-precondition", "The original inspection definition does not support this target.");
  }
  const classRow = await tx.get(`asset_classes/${target.assetClassId}`);
  if (!classRow.exists || classRow.data?.status !== "active" ||
      classRow.data.assetClassId !== target.assetClassId) {
    throw new WorkflowError("failed-precondition", "The original inspection asset class is not active.");
  }
  if (target.componentNodeId != null) {
    const node = await tx.get(`asset_hierarchy_nodes/${target.componentNodeId}`);
    if (!node.exists || node.data?.nodeId !== target.componentNodeId ||
        node.data.status !== "active" || node.data.assetClassId !== target.assetClassId) {
      throw new WorkflowError("failed-precondition", "The original inspection component is no longer active in its asset class.");
    }
  }
  const installed = target.subjectSerialNumber != null;
  let currentNumber = target.assetNumber;
  if (installed) {
    const profile = await tx.get(`inner_cover_profiles/${target.assetInstanceId}`);
    if (!profile.exists || profile.data == null || profile.data.innerCoverId !== target.assetInstanceId ||
        profile.data.assetClassId !== target.assetClassId ||
        profile.data.serialNumber !== target.subjectSerialNumber || profile.data.lifecycleState !== "installed") {
      throw new WorkflowError("failed-precondition", "The original Inner Cover must be installed with the same serial identity before follow-up.",
        {reasonCode: "inspection-context-subject-changed"});
    }
    currentNumber = intValue(profile.data.currentBaseAssetNumber, "currentBaseAssetNumber", 1);
  }
  const assets = await resolveInspectionPopulationAssets({
    tx, populationMode: installed ? "installedInnerCoversByBase" : "assetInstances",
    assetTypeKey: target.assetTypeKey, assetClassId: target.assetClassId,
    hostAssetClassId: target.hostAssetClassId, targetAssetNumbers: [currentNumber],
  });
  const at = iso(context.serverNow);
  const current = buildInspectionTargetPopulation({
    assetTypeKey: target.assetTypeKey, assetClassId: target.assetClassId, assets,
    componentNodeIds: target.componentNodeId == null ? [] : [target.componentNodeId],
    physicalPositions: target.physicalPosition == null ? [] : [target.physicalPosition],
    at, actorUid: context.actor.uid, actorName: context.actor.name, addedLater: false,
  })[0];
  if (!sameInspectionPhysicalTarget(target, current)) {
    throw new WorkflowError("failed-precondition", "The review cannot replace the campaign's original physical subject.",
      {reasonCode: "inspection-context-subject-changed"});
  }
  const identity = inspectionContextIdentity(current);
  if (stableJson(identity) !== stableJson(command.payload.reviewedContext ?? null)) {
    throw new WorkflowError("aborted", "The physical context changed after you reviewed it. Refresh and review again.",
      {reasonCode: "inspection-context-review-stale"});
  }
  if (stableJson(identity) === stableJson(inspectionContextIdentity(previous))) {
    throw new WorkflowError("failed-precondition", "This inspection context is already current.");
  }
  const review = {
    schemaVersion: 1 as const, revision: expectedContextRevision + 1,
    auditId: command.commandId, reviewedAt: at, reviewedByUid: context.actor.uid,
    reviewedByName: context.actor.name, reason, context: current,
  };
  tx.create(auditPath, {
    schemaVersion: 1, auditId: command.commandId, campaignId, targetKey,
    operation: "revalidate-context", performedAt: at, performedByUid: context.actor.uid,
    performedByName: context.actor.name, reason,
    beforeJson: stableJson({revision: expectedContextRevision, context: inspectionContextIdentity(previous)}),
    afterJson: stableJson(review as unknown as JsonMap),
  });
  tx.update(`inspection_campaigns/${campaignId}`, {
    version: command.expectedVersion + 1,
    targetPopulation: inspectionTargetPopulationJson(targets.map((item) =>
      item.targetKey === targetKey ? {...item, contextReview: review} : item)),
    updatedAt: at, updatedByUid: context.actor.uid, updatedByName: context.actor.name,
  });
  return {resultKey: "inspection-target-context-revalidated", aggregateVersion: command.expectedVersion + 1,
    result: {campaignId, targetKey, contextRevision: review.revision, auditId: command.commandId}};
};
