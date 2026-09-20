import {WorkflowError} from "./errors";
import {EquipmentIdentity, equipmentIdentity} from "./paths";
import {WorkflowTransaction} from "./store";
import {Actor, JsonMap, WorkflowCommand, WorkflowCommandReceipt} from "./types";
import {assertEquipmentProjectionIdentity} from "./equipmentFacts";
import {createHash} from "crypto";
import {Timestamp} from "firebase-admin/firestore";
import {cleanText, intValue, persistedInstantText, stableJson} from "./utils";

/** Resolve legacy input without changing its receipt fingerprint. The register,
 * not an optional input field, owns the administrative deployment restriction. */
export async function resolveEquipmentRegistrySubject(
  tx: WorkflowTransaction, requested: EquipmentIdentity, current: JsonMap | null,
): Promise<{identity: EquipmentIdentity; permitsDeployment: boolean}> {
  const fail = (reasonCode: string): never => { throw new WorkflowError(
    "equipment-state-conflict", "The equipment register identity or service state needs review before release.", {reasonCode}); };
  let identity = requested;
  if (current != null) {
    const projected = equipmentIdentity(requested.assetTypeKey, requested.assetNumber,
      current.assetClassId, current.assetInstanceId);
    if ((current.assetClassId != null && projected.assetClassId == null) ||
        (current.assetInstanceId != null && projected.assetInstanceId == null)) {
      return fail("equipment-registry-subject-invalid");
    }
    if (requested.assetInstanceId == null) identity = projected;
    else assertEquipmentProjectionIdentity(current, requested);
    if (projected.assetInstanceId == null) {
      // A numbered legacy projection may predate a retired physical subject.
      // An active-only lookup cannot establish whose deployment history it is.
      const legacyKey = requested.assetTypeKey === "innerCover" ? "base" : requested.assetTypeKey;
      const [classes, assets] = await Promise.all([
        tx.query("asset_classes", [{field: "legacyAssetTypeKey", op: "==", value: legacyKey}]),
        tx.query("asset_instances", [{field: "assetNumber", op: "==", value: requested.assetNumber}]),
      ]);
      const classIds = new Set(classes.map((row) => row.path.split("/").pop()));
      const candidates = assets.filter((row) => classIds.has(row.data?.assetClassId as string));
      if (candidates.length !== 1 || (identity.assetInstanceId != null &&
          candidates[0].path !== `asset_instances/${identity.assetInstanceId}`)) {
        return fail("equipment-registry-subject-ambiguous");
      }
    }
  }
  const legacyKey = requested.assetTypeKey === "innerCover" ? "base" : requested.assetTypeKey;
  if (identity.assetInstanceId == null) {
    const classes = await tx.query("asset_classes", [{field: "legacyAssetTypeKey", op: "==", value: legacyKey}]);
    const active = classes.filter((row) => row.data?.status === "active" && row.data?.isDeleted !== true);
    if (active.length !== 1) return fail("equipment-registry-subject-unresolved");
    const classId = active[0].path.split("/").pop()!;
    const assets = await tx.query("asset_instances", [
      {field: "assetClassId", op: "==", value: classId},
      {field: "assetNumber", op: "==", value: identity.assetNumber},
    ]);
    if (assets.length !== 1) return fail("equipment-registry-subject-ambiguous");
    identity = equipmentIdentity(identity.assetTypeKey, identity.assetNumber, classId, assets[0].path.split("/").pop());
  }
  const asset = await tx.get(`asset_instances/${identity.assetInstanceId}`);
  const cls = await tx.get(`asset_classes/${identity.assetClassId}`);
  const data = asset.data;
  if (!asset.exists || data == null || data.schemaVersion !== 1 ||
      data.assetInstanceId !== identity.assetInstanceId || data.assetClassId !== identity.assetClassId ||
      data.assetNumber !== identity.assetNumber || !cls.exists || cls.data?.status !== "active" ||
      cls.data?.isDeleted === true ||
      (identity.assetTypeKey !== "governedCustom" && cls.data?.legacyAssetTypeKey !== legacyKey) ||
      !["inService", "standby", "outOfService"].includes(data.serviceState as string) ||
      !["active", "retired"].includes(data.status as string)) return fail("equipment-registry-subject-invalid");
  return {identity, permitsDeployment: data.status === "active" && data.isDeleted !== true && data.serviceState !== "outOfService"};
}

const rebindRefusal = (reasonCode: string): never => {
  throw new WorkflowError("equipment-state-conflict",
    "The replacement equipment identity needs a fresh Admin/SI review before rebinding.", {reasonCode});
};

/** Store the complete old projection as JSON text so native timestamps cannot
 * break the workflow timeline's JSON payload reader or lose sub-ms precision. */
export function equipmentProjectionArchive(value: JsonMap): string {
  const encode = (item: unknown): unknown => {
    if (item instanceof Timestamp) return {type: "firestoreTimestamp", seconds: item.seconds, nanoseconds: item.nanoseconds};
    if (item instanceof Date && Number.isFinite(item.getTime())) return {type: "date", iso: item.toISOString()};
    if (item === null || typeof item === "string" || typeof item === "boolean" ||
        (typeof item === "number" && Number.isFinite(item))) return item;
    if (Array.isArray(item)) return item.map(encode);
    if (typeof item === "object" && Object.getPrototypeOf(item) === Object.prototype) {
      return Object.fromEntries(Object.entries(item).map(([key, child]) => [key, encode(child)]));
    }
    return rebindRefusal("equipment-rebinding-projection-archive-invalid");
  };
  const archived = stableJson(encode(value) as JsonMap);
  if (Buffer.byteLength(archived, "utf8") > 262144) rebindRefusal("equipment-rebinding-projection-archive-oversized");
  return archived;
}

export function equipmentRebindingEvidenceDigest(event: JsonMap): string {
  // The persistence adapter converts this one generated ISO instant to a native
  // timestamp. Do not round a later sub-millisecond alteration into acceptance.
  const at = event.occurredAt;
  const occurredAt = at instanceof Timestamp && at.nanoseconds % 1_000_000 === 0 ?
    at.toDate().toISOString() : at instanceof Date && Number.isFinite(at.getTime()) ? at.toISOString() : at;
  return `equipmentrebind1-sha256:${createHash("sha256")
    .update(stableJson({...event, occurredAt}), "utf8").digest("hex")}`;
}

/** A changed physical subject is an explicit reviewed reconciliation, never a
 * side effect of deployment or a legacy number-only lookup. */
export async function resolveReviewedEquipmentRegistryRebinding(
  tx: WorkflowTransaction, requested: EquipmentIdentity, current: JsonMap | null, raw: unknown,
): Promise<{identity: EquipmentIdentity; permitsDeployment: boolean; evidence: JsonMap}> {
  if (raw == null || typeof raw !== "object" || Array.isArray(raw)) rebindRefusal("equipment-rebinding-review-invalid");
  const review = raw as JsonMap;
  const fields = ["previousAssetClassId", "previousAssetInstanceId", "expectedPreviousAssetVersion", "expectedTargetAssetVersion", "reason"];
  if (Object.keys(review).sort().join(",") !== fields.sort().join(",") ||
      !Number.isSafeInteger(review.expectedPreviousAssetVersion) || (review.expectedPreviousAssetVersion as number) < 1 ||
      !Number.isSafeInteger(review.expectedTargetAssetVersion) || (review.expectedTargetAssetVersion as number) < 1 ||
      typeof review.reason !== "string" || !review.reason.trim() || review.reason.trim().length > 2000) {
    rebindRefusal("equipment-rebinding-review-invalid");
  }
  const previous = equipmentIdentity(requested.assetTypeKey, requested.assetNumber,
    review.previousAssetClassId, review.previousAssetInstanceId);
  if (!["base", "furnace", "forceCooler", "innerCover"].includes(requested.assetTypeKey) ||
      requested.assetClassId == null || requested.assetInstanceId == null ||
      previous.assetClassId == null || previous.assetInstanceId == null ||
      previous.assetInstanceId === requested.assetInstanceId || current == null ||
      !Number.isSafeInteger(current.version) || (current.version as number) < 1 ||
      current.assetTypeKey !== requested.assetTypeKey || current.assetNumber !== requested.assetNumber ||
      current.assetClassId !== previous.assetClassId || current.assetInstanceId !== previous.assetInstanceId) {
    rebindRefusal("equipment-rebinding-prior-projection-changed");
  }
  const legacyKey = requested.assetTypeKey === "innerCover" ? "base" : requested.assetTypeKey;
  const [oldAsset, oldClass, targetAsset, targetClass, classes, numberedAssets, workflows] = await Promise.all([
    tx.get(`asset_instances/${previous.assetInstanceId}`), tx.get(`asset_classes/${previous.assetClassId}`),
    tx.get(`asset_instances/${requested.assetInstanceId}`), tx.get(`asset_classes/${requested.assetClassId}`),
    tx.query("asset_classes", [{field: "legacyAssetTypeKey", op: "==", value: legacyKey}]),
    tx.query("asset_instances", [{field: "assetNumber", op: "==", value: requested.assetNumber}]),
    tx.query("maintenance_workflows", [{field: "assetTypeKey", op: "==", value: requested.assetTypeKey},
      {field: "assetNumber", op: "==", value: requested.assetNumber}]),
  ]);
  const old = oldAsset.data;
  const priorClass = oldClass.data;
  if (!oldAsset.exists || old == null || old.schemaVersion !== 1 || old.isDeleted === true ||
      old.assetClassId !== previous.assetClassId || old.assetInstanceId !== previous.assetInstanceId ||
      old.assetNumber !== requested.assetNumber || old.status !== "retired" ||
      old.version !== review.expectedPreviousAssetVersion || !oldClass.exists || priorClass == null ||
      priorClass.schemaVersion !== 1 || priorClass.assetClassId !== previous.assetClassId || priorClass.isDeleted === true ||
      !["active", "retired"].includes(priorClass.status as string) || priorClass.legacyAssetTypeKey !== legacyKey) {
    rebindRefusal("equipment-rebinding-previous-subject-changed");
  }
  const target = targetAsset.data;
  const cls = targetClass.data;
  const activeClasses = classes.filter((row) => row.data?.status === "active" && row.data?.isDeleted !== true);
  const activeAssets = numberedAssets.filter((row) => row.data?.assetClassId === requested.assetClassId &&
    row.data?.status === "active" && row.data?.isDeleted !== true);
  if (!targetAsset.exists || target == null || target.schemaVersion !== 1 || target.isDeleted === true ||
      target.assetClassId !== requested.assetClassId || target.assetInstanceId !== requested.assetInstanceId ||
      target.assetNumber !== requested.assetNumber || target.status !== "active" ||
      target.version !== review.expectedTargetAssetVersion ||
      !["inService", "standby", "outOfService"].includes(target.serviceState as string) ||
      !targetClass.exists || cls == null || cls.schemaVersion !== 1 || cls.assetClassId !== requested.assetClassId ||
      cls.status !== "active" || cls.isDeleted === true || cls.legacyAssetTypeKey !== legacyKey ||
      activeClasses.length !== 1 || activeClasses[0].path !== `asset_classes/${requested.assetClassId}` ||
      activeAssets.length !== 1 || activeAssets[0].path !== `asset_instances/${requested.assetInstanceId}`) {
    rebindRefusal("equipment-rebinding-target-subject-changed");
  }
  for (const row of workflows) {
    const data = row.data;
    if (data != null && (data.status === "completed" || data.status === "cancelled" || data.cancelled === true)) continue;
    if (data == null || data.assetClassId !== requested.assetClassId || data.assetInstanceId !== requested.assetInstanceId) {
      rebindRefusal("equipment-rebinding-workflow-review-required");
    }
  }
  return {identity: requested, permitsDeployment: target!.serviceState !== "outOfService", evidence: {
    schemaVersion: 1, ...review, reason: (review.reason as string).trim(),
    assetClassId: requested.assetClassId, assetInstanceId: requested.assetInstanceId,
    previousProjectionJson: equipmentProjectionArchive(current!),
  }};
}

/** Replays depend on the immutable accepted event, not today's replacement or
 * the current shared slot, which may legitimately have changed again. */
export async function verifyEquipmentRebindingReplay(args: {
  tx: WorkflowTransaction; command: WorkflowCommand; actor: Actor; receipt: WorkflowCommandReceipt;
}): Promise<void> {
  if (args.command.commandType !== "reconcileEquipment" || args.command.payload.registryRebinding == null) return;
  const event = await args.tx.get(`maintenance_workflow_events/${args.command.commandId}`);
  const data = event.data;
  const payload = data?.payload;
  const result = args.receipt.result;
  const expectedIdentity = equipmentIdentity(cleanText(args.command.payload.assetTypeKey, "assetTypeKey"),
    intValue(args.command.payload.assetNumber, "assetNumber", 1),
    args.command.payload.assetClassId, args.command.payload.assetInstanceId);
  const eventPayload = payload as JsonMap | undefined;
  const review = args.command.payload.registryRebinding as JsonMap;
  const acceptedReview = eventPayload?.registryRebinding as JsonMap | undefined;
  if (!event.exists || data == null || data.eventType !== "equipment.reconciled" ||
      data.aggregateId !== args.command.aggregateId || data.commandId !== args.command.commandId ||
      data.actorUid !== args.actor.uid || persistedInstantText(data.occurredAt) !== args.receipt.appliedAt ||
      args.receipt.resultKey !== "equipment-reconciled" || result.rebound !== true ||
      result.auditId !== args.command.commandId || result.assetClassId !== expectedIdentity.assetClassId ||
      result.assetInstanceId !== expectedIdentity.assetInstanceId || payload == null ||
      typeof payload !== "object" || Array.isArray(payload) ||
      args.receipt.aggregateVersion !== args.command.expectedVersion + 1 ||
      result.state !== eventPayload?.state || result.assetTypeKey !== expectedIdentity.assetTypeKey ||
      result.assetNumber !== expectedIdentity.assetNumber ||
      eventPayload?.assetTypeKey !== result.assetTypeKey || eventPayload?.assetNumber !== result.assetNumber ||
      acceptedReview == null || acceptedReview.schemaVersion !== 1 ||
      acceptedReview.assetClassId !== result.assetClassId || acceptedReview.assetInstanceId !== result.assetInstanceId ||
      acceptedReview.previousAssetClassId !== review.previousAssetClassId ||
      acceptedReview.previousAssetInstanceId !== review.previousAssetInstanceId ||
      acceptedReview.expectedPreviousAssetVersion !== review.expectedPreviousAssetVersion ||
      acceptedReview.expectedTargetAssetVersion !== review.expectedTargetAssetVersion ||
      typeof review.reason !== "string" || acceptedReview.reason !== review.reason.trim() ||
      typeof acceptedReview.previousProjectionJson !== "string" ||
      typeof acceptedReview.replacementProjectionJson !== "string" ||
      result.rebindingEvidenceSha256 !== equipmentRebindingEvidenceDigest(data)) {
    throw new WorkflowError("failed-precondition", "The accepted equipment rebinding evidence is missing or changed.",
      {reasonCode: "equipment-rebinding-replay-evidence-invalid"});
  }
}
