import {WorkflowError} from "./errors";
import {JsonMap} from "./types";
import {persistedInstantText, stableJson} from "./utils";

const text = (value: unknown): value is string => typeof value === "string" &&
  value.length > 0 && value === value.trim();
const object = (value: unknown): value is JsonMap => value != null &&
  typeof value === "object" && !Array.isArray(value);
const positive = (value: unknown): boolean => Number.isSafeInteger(value) && (value as number) > 0;

const review = (): never => {
  throw new WorkflowError("failed-precondition",
    "The original physical identity of this inspection or maintenance issue is incomplete. Review the historical evidence before linking corrective work.",
    {reasonCode: "inspection-corrective-subject-review-required"});
};
const mismatch = (): never => {
  throw new WorkflowError("failed-precondition",
    "This maintenance issue belongs to a different physical inspection subject.",
    {reasonCode: "inspection-corrective-subject-mismatch"});
};

/** Compare original canonical evidence, never today's occupant of a Base.
 * A linked Inner Cover ticket's registry reference describes its host; the
 * contemporaneous association identifies the actual serial being repaired.
 * Version/name changes do not change physical identity. Insufficient legacy
 * evidence requires review rather than a number-only compatibility fallback.
 */
function requireInspectionSameAsset(
  ticket: JsonMap, ticketId: string, observation: JsonMap,
): void {
  if (ticket.firestoreId !== ticketId || ticket.isDeleted !== false ||
      !text(observation.assetTypeKey) || !text(observation.assetClassId) ||
      !text(observation.assetInstanceId) || !positive(observation.assetNumber) ||
      typeof ticket.assetHierarchyRefJson !== "string") return review();
  let reference: unknown;
  try { reference = JSON.parse(ticket.assetHierarchyRefJson as string); } catch { review(); }
  if (!object(reference) || !text(reference.assetClassId) || !text(reference.assetInstanceId) ||
      !positive(reference.assetNumber) || !positive(reference.assetInstanceVersion) ||
      !((reference.schemaVersion === 3 && reference.scope === "physicalAsset") ||
        ([2, 3].includes(reference.schemaVersion as number) && reference.scope === "installedComponent") ||
        (reference.schemaVersion === 4 && reference.scope === "componentDefinitionOnAsset")) ||
      reference.assetNumber !== ticket.assetNumber) return review();
  if (ticket.assetType !== observation.assetTypeKey) return mismatch();
  if (observation.assetTypeKey !== "innerCover") {
    if (reference.assetClassId !== observation.assetClassId ||
        reference.assetInstanceId !== observation.assetInstanceId ||
        reference.assetNumber !== observation.assetNumber) return mismatch();
    return;
  }
  const association = reference.innerCoverAssociation;
  const observedAt = persistedInstantText(observation.observedAt);
  const observedLinkedAt = persistedInstantText(observation.linkedAt);
  if (!object(association) || association.positionState !== "linked" ||
      !text(association.innerCoverId) || !text(association.innerCoverSerialNumber) ||
      !text(association.linkageId) || !positive(association.assignmentVersion) ||
      association.baseAssetInstanceId !== reference.assetInstanceId ||
      association.baseAssetNumber !== reference.assetNumber ||
      !text(observation.subjectSerialNumber) || !text(observation.hostAssetClassId) ||
      !text(observation.hostAssetInstanceId) || !text(observation.linkageId) ||
      observation.hostAssetNumber !== observation.assetNumber ||
      observedAt == null || observedLinkedAt == null ||
      Date.parse(observedAt) < Date.parse(observedLinkedAt)) return review();
  const eventAt = persistedInstantText(association.eventAt);
  const linkedAt = persistedInstantText(association.linkedAt);
  const ticketStart = persistedInstantText(ticket.startDate);
  if (eventAt == null || linkedAt == null || eventAt !== ticketStart ||
      Date.parse(eventAt) < Date.parse(linkedAt)) return review();
  if (association.innerCoverId !== observation.assetInstanceId ||
      association.innerCoverSerialNumber !== observation.subjectSerialNumber) return mismatch();
}

function scopeKey(ticket: JsonMap): string {
  const ref = JSON.parse(ticket.assetHierarchyRefJson as string) as JsonMap;
  return stableJson({scope: ref.scope, assetClassId: ref.assetClassId,
    assetInstanceId: ref.assetInstanceId, nodeId: ref.nodeId ?? null,
    componentInstanceId: ref.componentInstanceId ?? null,
    innerCoverId: object(ref.innerCoverAssociation) ? ref.innerCoverAssociation.innerCoverId : null});
}

/** A definition is not an installed serial or a position. Broader work may
 * cover the target only through an explicit, immutable supervisor review. */
export function requireInspectionCorrectiveSubject(
  ticket: JsonMap, ticketId: string, observation: JsonMap, scopeReview?: unknown,
): void {
  requireInspectionSameAsset(ticket, ticketId, observation);
  const ref = JSON.parse(ticket.assetHierarchyRefJson as string) as JsonMap;
  const exactScope = observation.physicalPosition == null &&
    (observation.componentNodeId == null ? ref.scope === "physicalAsset" :
      ref.scope === "componentDefinitionOnAsset" && ref.nodeId === observation.componentNodeId);
  if (exactScope) return;
  if (object(scopeReview) && scopeReview.schemaVersion === 1 &&
      scopeReview.ticketId === ticketId && scopeReview.targetKey === observation.targetKey &&
      scopeReview.componentNodeId === (observation.componentNodeId ?? null) &&
      scopeReview.physicalPosition === (observation.physicalPosition ?? null) &&
      scopeReview.ticketScopeKey === scopeKey(ticket) &&
      scopeReview.ticketDescription === (ticket.description ?? null) &&
      text(scopeReview.reviewedByUid) && text(scopeReview.reason) &&
      positive(scopeReview.reviewedTicketVersion) &&
      persistedInstantText(scopeReview.reviewedAt) != null) return;
  throw new WorkflowError("failed-precondition",
    "This repair does not establish the exact inspected component and position. A supervisor must review and record how the work covers this target.",
    {reasonCode: "inspection-corrective-scope-review-required"});
}

export function inspectionCorrectiveScopeReview(
  ticket: JsonMap, ticketId: string, observation: JsonMap,
  request: unknown, roles: ReadonlySet<string>, uid: string, name: string, at: string,
): JsonMap | null {
  requireInspectionSameAsset(ticket, ticketId, observation);
  if (request == null) return null;
  if (!["admin", "si", "contractSupervisor", "shiftSupervisor"].some((role) => roles.has(role))) {
    throw new WorkflowError("permission-denied", "A supervisor must review corrective-work applicability.");
  }
  if (!object(request) || Object.keys(request).sort().join(",") !== "expectedTicketVersion,reason" ||
      !positive(request.expectedTicketVersion) || !text(request.reason) || request.reason.length > 1000) {
    throw new WorkflowError("invalid-argument", "Corrective scope review needs the reviewed ticket version and a reason.");
  }
  if (ticket.version !== request.expectedTicketVersion) {
    throw new WorkflowError("aborted", "The maintenance issue changed after review. Review it again.");
  }
  return {schemaVersion: 1, ticketId, targetKey: observation.targetKey,
    componentNodeId: observation.componentNodeId ?? null, physicalPosition: observation.physicalPosition ?? null,
    ticketScopeKey: scopeKey(ticket), ticketDescription: ticket.description ?? null,
    reviewedTicketVersion: ticket.version, reviewedByUid: uid, reviewedByName: name,
    reviewedAt: at, reason: request.reason};
}
