import {HttpsError} from "firebase-functions/v2/https";
import {canonicalApprovedUserAuthority} from "./userAuthority";

type JsonMap = {[key: string]: unknown};
export type OriginBoundCallableName =
  "mutateAssetHierarchyV2" | "executeMaintenanceWorkflowCommandV2" |
  "mutateChargeAbnormalityV2" | "assignPublishedTemplateVersionV2";

const CONTRACTS = Object.freeze({
  mutateChargeAbnormalityV2: Object.freeze({
    payloadKey: "request",
    capabilityRevision: "chargeAbnormality.v2.20260913",
    capabilities: Object.freeze(["chargeAbnormality.v2", "qualityMonitoring.v1", "savedSubmissionReview.v1"]),
  }),
  assignPublishedTemplateVersionV2: Object.freeze({
    payloadKey: "request",
    capabilityRevision: "publishedTemplateAssignment.v2.20260913",
    capabilities: Object.freeze(["publishedTemplateAssignment.v2", "savedSubmissionReview.v1"]),
  }),
  mutateAssetHierarchyV2: Object.freeze({
    payloadKey: "request",
    capabilityRevision: "assetHierarchy.v2.20260913",
    capabilities: Object.freeze([
      "assetHierarchy.v2", "innerCoverAcceptance.v1",
      "morningReviewExpectedPlantDay.v1", "morningReviewReceiptLookup.v1",
      "savedSubmissionReview.v1",
    ]),
  }),
  executeMaintenanceWorkflowCommandV2: Object.freeze({
    payloadKey: "command",
    capabilityRevision: "maintenanceWorkflow.v2.20260913",
    capabilities: Object.freeze([
      "maintenanceWorkflow.v2", "inspectionFindingExpectedVersion.v1",
      "inspectionCampaignReopen.v1", "maintenancePlanRevalidation.v1",
      "inspectionTargetContextRevalidation.v1",
      "savedSubmissionReview.v1",
    ]),
  }),
});

function invalidEnvelope(): never {
  throw new HttpsError(
    "invalid-argument", "The origin-bound command envelope is invalid.",
    {reasonCode: "origin-bound-envelope-invalid"},
  );
}

/**
 * The authenticated outer request is the only authority source. The origin is
 * part of the frozen client envelope; it must never be inferred from login.
 * Probe replies come from the executable endpoint, not release metadata.
 */
export async function executeOriginBoundCallable<T>(args: {
  callableName: OriginBoundCallableName;
  authUid: string | null;
  data: unknown;
  readActor: (uid: string) => Promise<JsonMap | null>;
  execute: (payload: JsonMap) => Promise<T>;
  lookupReceipt?: (payload: JsonMap) => Promise<JsonMap | T>;
  recoverSubmission?: (payload: JsonMap) => Promise<JsonMap>;
}): Promise<T | JsonMap> {
  if (args.authUid == null || args.authUid.length === 0) {
    throw new HttpsError("unauthenticated", "Sign in is required.");
  }
  if (args.data == null || typeof args.data !== "object" || Array.isArray(args.data)) {
    invalidEnvelope();
  }
  const data = args.data as JsonMap;
  const contract = CONTRACTS[args.callableName];
  const probe = Object.prototype.hasOwnProperty.call(data, "probe");
  const lookup = Object.prototype.hasOwnProperty.call(data, "receiptLookup");
  const recovery = Object.prototype.hasOwnProperty.call(data, "recovery");
  const requiredKeys = ["protocolVersion", "originActorUid",
    probe ? "probe" : lookup ? "receiptLookup" : recovery ? "recovery" : contract.payloadKey].sort();
  if (Object.keys(data).sort().join(",") !== requiredKeys.join(",") ||
      data.protocolVersion !== 2 || typeof data.originActorUid !== "string" ||
      data.originActorUid.length === 0 || data.originActorUid !== data.originActorUid.trim()) {
    invalidEnvelope();
  }
  // Check before account reads, abuse-control admission, or business writes.
  if (data.originActorUid !== args.authUid) {
    throw new HttpsError(
      "permission-denied", "This saved command belongs to a different account.",
      {reasonCode: "origin-bound-actor-mismatch"},
    );
  }
  if (probe) {
    if (data.probe !== "capabilities") invalidEnvelope();
    const actor = await args.readActor(args.authUid);
    if (actor == null || canonicalApprovedUserAuthority(actor) == null) {
      throw new HttpsError("permission-denied", "An approved account is required.");
    }
    return {
      schemaVersion: 1, callableName: args.callableName, protocolVersion: 2,
      capabilityRevision: contract.capabilityRevision,
      capabilities: [...contract.capabilities],
    };
  }
  if (recovery) {
    const payload = data.recovery;
    if (args.recoverSubmission == null || payload == null ||
        typeof payload !== "object" || Array.isArray(payload)) invalidEnvelope();
    return args.recoverSubmission(payload as JsonMap);
  }
  if (lookup) {
    const payload = data.receiptLookup;
    if (args.lookupReceipt == null || payload == null ||
        typeof payload !== "object" || Array.isArray(payload)) invalidEnvelope();
    return args.lookupReceipt(payload as JsonMap);
  }
  const payload = data[contract.payloadKey];
  if (payload == null || typeof payload !== "object" || Array.isArray(payload)) invalidEnvelope();
  // The original V1 handler remains the single authority, rate-limit, request
  // fingerprint, mutation, and accepted-replay implementation for both routes.
  return args.execute(payload as JsonMap);
}
