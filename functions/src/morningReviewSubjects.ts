import {AssetHierarchyMutationError} from "./assetHierarchyMutation";
import type {MorningReviewFirestoreLike} from "./morningReviewMutation";
type MapValue = {[key: string]: unknown};
type Transaction = Parameters<Parameters<MorningReviewFirestoreLike["runTransaction"]>[0]>[0];

export async function resolveMorningReviewSubject(db: MorningReviewFirestoreLike, tx: Transaction,
  draft: {assetClassId: string | null; assetClassName: string | null; assetInstanceId: string | null; assetNumber: string | null},
): Promise<{assetClassName: string | null; assetNumber: string | null}> {
  const provisional = draft.assetClassId?.startsWith("meeting-provisional:") === true;
  if (provisional || draft.assetInstanceId?.startsWith("meeting-provisional:") === true) {
    if (!provisional || !draft.assetInstanceId?.startsWith(`${draft.assetClassId}:`) ||
        !draft.assetClassName || !draft.assetNumber) {
      throw new AssetHierarchyMutationError("invalid-argument", "Provisional meeting subject identity is inconsistent.");
    }
    // Explicit meeting identity; never queried or labelled as a plant register row.
    return {assetClassName: draft.assetClassName, assetNumber: draft.assetNumber};
  }
  if (draft.assetClassId == null) return {assetClassName: null, assetNumber: null};
  const classRow = await tx.get(db.collection("asset_classes").doc(draft.assetClassId));
  const assetClass = "exists" in classRow && classRow.exists ? classRow.data() : null;
  const instanceRow = draft.assetInstanceId == null ? null : await tx.get(db.collection("asset_instances").doc(draft.assetInstanceId));
  const instance = instanceRow != null && "exists" in instanceRow && instanceRow.exists ? instanceRow.data() : null;
  if (assetClass == null || (draft.assetInstanceId != null && instance == null)) {
    throw new AssetHierarchyMutationError("failed-precondition", "The selected registered subject does not exist.",
      {reasonCode: "morning-review-action-asset-unknown"});
  }
  if (instance != null && instance.assetClassId !== draft.assetClassId) {
    throw new AssetHierarchyMutationError("failed-precondition", "The selected subject belongs to another class.",
      {reasonCode: "morning-review-action-asset-mismatch"});
  }
  const inactive = (row: MapValue) => row.isActive === false || row.isDeleted === true ||
    row.status === "retired" || row.status === "inactive";
  if (inactive(assetClass) || (instance != null && inactive(instance))) {
    throw new AssetHierarchyMutationError("failed-precondition", "Select an active registered subject, or record a general historical discussion.",
      {reasonCode: "morning-review-subject-inactive"});
  }
  if (typeof assetClass.name !== "string" || !assetClass.name.trim() ||
      (instance != null && instance.assetNumber == null)) {
    throw new AssetHierarchyMutationError("data-loss", "The registered subject has incomplete identity evidence.");
  }
  return {assetClassName: assetClass.name.trim(), assetNumber: instance == null ? null : String(instance.assetNumber)};
}
