import {WorkflowError} from "./errors";
import {EquipmentIdentity, equipmentIdentity} from "./paths";
import {WorkflowTransaction} from "./store";
import {JsonMap} from "./types";
import {assertEquipmentProjectionIdentity} from "./equipmentFacts";

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
