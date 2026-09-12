import {WorkflowError} from "./errors";
import {JsonMap} from "./types";
import {persistedInstantText} from "./utils";

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
export function requireInspectionCorrectiveSubject(
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
