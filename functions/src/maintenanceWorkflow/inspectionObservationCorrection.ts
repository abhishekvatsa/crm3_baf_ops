import {WorkflowError} from "./errors";
import {WorkflowTransaction} from "./store";
import {JsonMap} from "./types";
import {persistedInstantText, stableJson} from "./utils";
import {InspectionCampaignTarget, parseInspectionTargetPopulation} from "./inspectionPopulation";
import {requireInspectionContextReview} from "./inspectionTargetContextHandlers";

function refuse(): never {
  throw new WorkflowError("failed-precondition",
    "The original inspection context needs review before this reading can be corrected.",
    {reasonCode: "inspection-correction-context-evidence-invalid"});
}

/** The current campaign revision is a command precondition, not permission to
 * move a correction into a later installation. Reconstruct its original context
 * exclusively from the immutable baseline or its authenticated historical audit.
 */
export async function requireInspectionCorrectionContext(
  tx: WorkflowTransaction, campaignId: string, baseline: InspectionCampaignTarget,
  original: JsonMap, payload: JsonMap, observedAt: string,
): Promise<InspectionCampaignTarget> {
  const revision = original.targetContextRevision ?? 0;
  if (!Number.isSafeInteger(revision) || (revision as number) < 0 ||
      (revision as number) > (baseline.contextReview?.revision ?? 0) ||
      original.observationId !== payload.supersedesObservationId ||
      original.targetKey !== baseline.targetKey) refuse();
  let historical = {...baseline};
  delete historical.contextReview;
  if (revision === 0) {
    if (original.targetContextAuditId != null || original.targetContextOriginalLinkageId != null) refuse();
  } else {
    const auditId = original.targetContextAuditId;
    if (typeof auditId !== "string" || !auditId || auditId.includes("/") ||
        original.targetContextOriginalLinkageId !== baseline.linkageId) refuse();
    const audit = await tx.get(`inspection_target_audits/${auditId}`);
    if (typeof audit.data?.afterJson !== "string") refuse();
    let review: unknown;
    try {
      review = JSON.parse(audit.data!.afterJson as string);
    } catch {
      refuse();
    }
    historical = parseInspectionTargetPopulation([{...historical, contextReview: review}])[0];
    if (historical.contextReview?.revision !== revision || historical.contextReview?.auditId !== auditId) refuse();
    historical = await requireInspectionContextReview(tx, campaignId, historical);
  }
  const identityFields = ["assetTypeKey", "assetClassId", "assetInstanceId", "assetNumber",
    "hostAssetClassId", "hostAssetInstanceId", "hostAssetInstanceVersion", "hostAssetNumber",
    "hostAssetInstanceName", "subjectSerialNumber", "linkageId", "linkageVersion", "linkedAt",
    "componentNodeId", "physicalPosition"];
  if (identityFields.some((key) => {
    const actual = original[key] ?? null;
    if (key !== "linkedAt" || actual == null) return actual !== (historical[key] ?? null);
    const instant = persistedInstantText(actual);
    return instant == null || instant !== historical.linkedAt;
  })) refuse();
  // Metadata is part of the original reading, even if the live component has
  // since been renamed, revised or retired. The client may not supply a new one.
  if (["componentNodeId", "componentNodeVersion", "componentName", "physicalPosition"]
    .some((key) => (payload[key] ?? null) !== (original[key] ?? null)) ||
      !Array.isArray(original.hierarchyPath) ||
      original.hierarchyPath.some((part) => typeof part !== "string" || !part.trim()) ||
      stableJson({path: payload.hierarchyPath}) !== stableJson({path: original.hierarchyPath})) refuse();
  if (historical.componentNodeId != null &&
      (!Number.isSafeInteger(original.componentNodeVersion) || (original.componentNodeVersion as number) < 1 ||
       typeof original.componentName !== "string" || !original.componentName.trim())) refuse();
  if (historical.linkageId != null) {
    // A retired installation remains valid history. Its identity and end time
    // must agree; its current active flag, assignment and profile version need
    // not match the old snapshot. This also bounds a corrected event time.
    const linkage = await tx.get(`inner_cover_linkages/${historical.linkageId}`);
    const row = linkage.data;
    if (!linkage.exists || row == null || row.schemaVersion !== 1 || row.linkageId !== historical.linkageId ||
        row.baseAssetInstanceId !== historical.hostAssetInstanceId ||
        row.baseAssetClassId !== historical.hostAssetClassId ||
        row.baseAssetNumber !== historical.hostAssetNumber || row.baseAssetName !== historical.hostAssetInstanceName ||
        row.innerCoverId !== historical.assetInstanceId ||
        row.innerCoverSerialNumber !== historical.subjectSerialNumber ||
        persistedInstantText(row.installedAt) !== historical.linkedAt ||
        !Number.isSafeInteger(row.version) || (row.version as number) < historical.linkageVersion! ||
        (row.active !== true && row.active !== false)) refuse();
    const removedAt = row.removedAt == null ? null : persistedInstantText(row.removedAt);
    if ((row.active === true && row.removedAt != null) ||
        (row.active === false && removedAt == null)) refuse();
    const originalAt = persistedInstantText(original.observedAt);
    if (originalAt == null || historical.linkedAt == null ||
        Date.parse(originalAt) < Date.parse(historical.linkedAt) ||
        (removedAt != null && (Date.parse(removedAt) < Date.parse(historical.linkedAt) ||
          Date.parse(originalAt) >= Date.parse(removedAt) || Date.parse(observedAt) >= Date.parse(removedAt)))) {
      throw new WorkflowError("failed-precondition", "A correction must remain within the original Inner Cover installation.",
        {reasonCode: "inspection-correction-outside-linkage"});
    }
  }
  return historical;
}
