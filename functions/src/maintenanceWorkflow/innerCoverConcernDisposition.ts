import {createHash} from "crypto";
import {WorkflowError} from "./errors";
import {HandlerArgs, HandlerResult} from "./handlerTypes";
import {WorkflowTransaction} from "./store";
import {Actor, JsonMap, WorkflowCommand, WorkflowCommandReceipt} from "./types";
import {iso, payloadFingerprint, persistedInstantText, stableJson} from "./utils";

const fail = (message: string): never => {
  throw new WorkflowError("failed-precondition", message,
    {reasonCode: "inner-cover-assessment-evidence-required"});
};
const text = (value: unknown): value is string =>
  typeof value === "string" && value.trim().length > 0;
const positive = (value: unknown): value is number =>
  Number.isSafeInteger(value) && (value as number) > 0;
const object = (value: unknown): JsonMap => {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return fail("The retained assessment evidence is incomplete.");
  }
  return value as JsonMap;
};
const parsed = (value: unknown): JsonMap => {
  try { return object(JSON.parse(value as string)); } catch {
    return fail("The retained assessment evidence is unreadable.");
  }
};
const instant = (value: unknown): string => {
  if (value != null && typeof value === "object" && !(value instanceof Date)) {
    const nanos = (value as {_nanoseconds?: unknown})._nanoseconds;
    if (typeof nanos !== "number" || nanos % 1_000_000 !== 0) {
      return fail("The retained evidence time has unsupported precision.");
    }
  }
  return persistedInstantText(value) ?? fail("The retained evidence time is invalid.");
};
// Only these known persisted instant fields change representation at the
// Firestore boundary. Preserve every other field, including unexpected keys,
// so canonicalizing timestamps cannot conceal a changed disposition.
const canonicalDisposition = (value: unknown): JsonMap => {
  const data = object(value);
  return {...data, inspectedAt: instant(data.inspectedAt), settledAt: instant(data.settledAt)};
};
const digest = (value: JsonMap): string => createHash("sha256")
  .update(stableJson(value), "utf8").digest("hex");
const auditHash = (value: JsonMap, field: string): string =>
  digest({...value, [field]: instant(value[field])});
const load = async (tx: WorkflowTransaction, path: string): Promise<JsonMap> => {
  const value = await tx.get(path);
  return value.exists && value.data != null ? value.data :
    fail("Required server evidence is missing. Complete the recorded inspection first.");
};
const validatePayload = (command: WorkflowCommand): void => {
  const p = command.payload;
  const keys = ["innerCoverId", "innerCoverSerialNumber", "eventLinkageId",
    "expectedTicketVersion", "expectedCoverVersion", "acceptanceRequestId",
    "assessorConfirmed", "reason"].sort();
  if (JSON.stringify(Object.keys(p).sort()) !== JSON.stringify(keys) ||
      ![p.innerCoverId, p.innerCoverSerialNumber, p.eventLinkageId,
        p.acceptanceRequestId, p.reason].every(text) ||
      !positive(p.expectedTicketVersion) || !positive(p.expectedCoverVersion) ||
      p.assessorConfirmed !== true || (p.reason as string).trim().length < 20 ||
      (p.reason as string).trim().length > 2000) {
    throw new WorkflowError("invalid-argument",
      "Confirm the exact assessment and give a disposition reason of 20 to 2000 characters.");
  }
  if ([p.innerCoverId, p.eventLinkageId, p.acceptanceRequestId].some(
    (value) => (value as string).includes("/"))) {
    throw new WorkflowError("invalid-argument", "Evidence identifiers are invalid.");
  }
};
const IDENTITY = ["caseId", "ticketId", "baseAssetClassId", "baseAssetInstanceId",
  "baseAssetNumber", "furnaceAssetClassId", "furnaceAssetInstanceId", "furnaceAssetNumber",
  "innerCoverId", "innerCoverSerialNumber", "innerCoverLinkageId",
  "innerCoverAssignmentVersion", "reportedByUid"] as const;

function validateOriginal(c: JsonMap, t: JsonMap, command: WorkflowCommand): void {
  const p = command.payload;
  if (c.schemaVersion !== 1 || c.caseId !== command.aggregateId ||
      c.ticketId !== command.aggregateId || !positive(c.version) ||
      c.version !== command.expectedVersion || c.concernDisposition != null ||
      c.obstructionStatus !== "released" || c.adjudicationStatus !== "confirmed" ||
      !["innerCoverBulging", "combinedCondition"].includes(c.confirmedCause as string) ||
      c.innerCoverId !== p.innerCoverId || c.innerCoverSerialNumber !== p.innerCoverSerialNumber ||
      c.innerCoverLinkageId !== p.eventLinkageId || IDENTITY.some((key) => c[key] == null) ||
      t.firestoreId !== command.aggregateId || t.isDeleted !== true ||
      t.version !== p.expectedTicketVersion || t.assetType !== "furnace" ||
      t.assetNumber !== c.furnaceAssetNumber || t.classification !== "furnaceStuckup" ||
      ![t.deletedByUid, t.deletedByName, t.deleteReason].every(text)) {
    fail("Only the exact released, withdrawn, confirmed Inner Cover concern can be settled. Refresh its current evidence.");
  }
  const furnace = parsed(t.assetHierarchyRefJson);
  const base = parsed(t.stuckupBaseAssetRefJson);
  const link = object(base.innerCoverAssociation);
  if (furnace.assetClassId !== c.furnaceAssetClassId ||
      furnace.assetInstanceId !== c.furnaceAssetInstanceId ||
      base.assetClassId !== c.baseAssetClassId || base.assetInstanceId !== c.baseAssetInstanceId ||
      link.innerCoverId !== c.innerCoverId || link.innerCoverSerialNumber !== c.innerCoverSerialNumber ||
      link.linkageId !== c.innerCoverLinkageId || link.assignmentVersion !== c.innerCoverAssignmentVersion ||
      link.positionState !== "linked" || link.baseAssetInstanceId !== c.baseAssetInstanceId ||
      link.baseAssetNumber !== c.baseAssetNumber || instant(link.eventAt) !== instant(c.reportedAt) ||
      base.assetNumber !== c.baseAssetNumber || furnace.assetNumber !== c.furnaceAssetNumber ||
      t.stuckupSuspectedCause !== c.suspectedCause ||
      t.stuckupOperatingContext !== c.operatingContext ||
      t.chargeNoAtEvent !== c.chargeNoAtEvent ||
      instant(t.startDate) !== instant(c.reportedAt) ||
      instant(c.releasedAt) < instant(c.reportedAt) ||
      instant(c.adjudicatedAt) < instant(c.reportedAt)) {
    fail("The original issue does not match this exact cover and event. Reconciliation is required.");
  }
}

async function withdrawalProof(tx: WorkflowTransaction, t: JsonMap): Promise<JsonMap> {
  const candidates = await tx.query("audit_logs", [{field: "entityId", op: "==", value: t.firestoreId}]);
  const matches = candidates.filter(({data}) => data?.operation === "correctMaintenanceTicket" &&
    data.resultVersion === t.version && parsed(data.afterJson).isDeleted === true);
  if (matches.length !== 1) fail("The original audited withdrawal could not be verified.");
  const audit = matches[0].data!;
  const before = parsed(audit.beforeJson);
  const after = parsed(audit.afterJson);
  const receipt = await load(tx, `maintenance_workflow_command_receipts/${audit.requestId}`);
  const result = object(receipt.result);
  const at = instant(t.deletedAt);
  if (audit.schemaVersion !== 1 || audit.entityType !== "maintenance" ||
      audit.auditId !== `server_maintenance_ticket_${audit.requestId}` ||
      !positive(before.version) || before.version + 1 !== t.version || before.isDeleted !== false ||
      after.version !== t.version || after.firestoreId !== t.firestoreId ||
      after.deletedByUid !== t.deletedByUid || after.deletedByName !== t.deletedByName ||
      after.deleteReason !== t.deleteReason || instant(after.deletedAt) !== at ||
      audit.performedByUid !== t.deletedByUid || audit.performedByName !== t.deletedByName ||
      audit.reasonNotes !== t.deleteReason || instant(audit.timestamp) !== at ||
      receipt.receiptSchemaVersion !== 2 || receipt.commandId !== audit.requestId ||
      receipt.commandType !== "correctMaintenanceTicket" || receipt.aggregateId !== t.firestoreId ||
      receipt.actorUid !== t.deletedByUid || receipt.aggregateVersion !== t.version ||
      receipt.resultKey !== "maintenance-ticket-withdrawn" || instant(receipt.appliedAt) !== at ||
      result.ticketId !== t.firestoreId || result.auditId !== audit.auditId ||
      object(receipt.authorityScope).capability !== "ticket.correct" ||
      receipt.payloadFingerprint !== payloadFingerprint({commandId: audit.requestId!,
        commandType: "correctMaintenanceTicket", aggregateId: t.firestoreId!, expectedVersion: before.version!,
        payload: {corrections: {}, withdrawInError: true, reason: t.deleteReason!}}) ||
      stableJson(after) !== stableJson({...before, isDeleted: true, deletedAt: at,
        deletedByUid: t.deletedByUid!, deletedByName: t.deletedByName!,
        deleteReason: t.deleteReason!, version: t.version!})) {
    fail("The withdrawal audit and receipt do not agree. The original issue remains withdrawn.");
  }
  return {withdrawalAuditId: audit.auditId!, withdrawalRequestId: audit.requestId!,
    withdrawalAuditSha256: auditHash(audit, "timestamp"), withdrawalReceiptSha256: digest(receipt)};
}

async function acceptanceProof(tx: WorkflowTransaction, c: JsonMap, profile: JsonMap,
  command: WorkflowCommand, now: string): Promise<JsonMap> {
  const requestId = command.payload.acceptanceRequestId as string;
  const id = `inner_cover_${requestId}`;
  const [audit, receipt, assetClass] = await Promise.all([
    load(tx, `inner_cover_lifecycle_audits/${id}`),
    load(tx, `inner_cover_lifecycle_receipts/${requestId}`),
    load(tx, `asset_classes/${profile.assetClassId}`),
  ]);
  const before = parsed(audit.beforeJson);
  const after = parsed(audit.afterJson);
  const performed = instant(audit.performedAt);
  const inspected = instant(after.acceptedAt);
  const hash = auditHash(audit, "performedAt");
  if (profile.innerCoverId !== c.innerCoverId || profile.serialNumber !== c.innerCoverSerialNumber ||
      profile.version !== command.payload.expectedCoverVersion || profile.lastMutationId !== requestId ||
      profile.lifecycleState !== "available" || profile.currentBaseAssetInstanceId != null ||
      profile.currentBaseAssetNumber != null || profile.currentLinkageId != null ||
      assetClass.legacyAssetTypeKey !== "innerCover" || assetClass.status !== "active" ||
      audit.schemaVersion !== 1 || audit.auditId !== id || audit.entityType !== "inner_cover" ||
      audit.entityId !== c.innerCoverId || audit.operation !== "ACCEPT_INNER_COVER" ||
      audit.requestId !== requestId || !text(audit.performedByUid) || !text(audit.performedByName) ||
      audit.secondaryEntityId != null || audit.secondaryAfterJson != null ||
      receipt.schemaVersion !== 1 || receipt.requestId !== requestId || receipt.auditId !== id ||
      receipt.actorUid !== audit.performedByUid || receipt.innerCoverId !== c.innerCoverId ||
      receipt.operation !== "ACCEPT_INNER_COVER" || receipt.version !== profile.version ||
      receipt.secondaryVersion != null || !text(receipt.fingerprint) ||
      receipt.fingerprint !== audit.fingerprint || receipt.auditEvidenceSha256 !== hash ||
      stableJson(receipt.timestampInstants ?? null) !== stableJson(audit.timestampInstants ?? null) ||
      instant(receipt.committedAt) !== performed || receipt.committedAtIso !== performed ||
      before.innerCoverId !== c.innerCoverId || before.serialNumber !== c.innerCoverSerialNumber ||
      !positive(before.version) || before.version + 1 !== after.version ||
      !["awaitingInspection", "underInspection"].includes(before.lifecycleState as string) ||
      after.version !== profile.version || after.innerCoverId !== c.innerCoverId ||
      after.serialNumber !== c.innerCoverSerialNumber || after.lifecycleState !== "available" ||
      after.currentBaseAssetInstanceId != null || after.currentLinkageId != null ||
      after.acceptedByUid !== audit.performedByUid || after.acceptedByName !== audit.performedByName ||
      ![after.acceptanceReference, after.acceptanceNotes, after.assuranceEpisodeId].every(text) ||
      inspected <= instant(c.reportedAt) || inspected <= instant(c.releasedAt) ||
      inspected <= instant(c.adjudicatedAt) || inspected > performed || performed > now) {
    fail("A new recorded inspection and acceptance after this event is required. Delink the cover, inspect and accept it, then return here.");
  }
  for (const key of ["acceptanceReference", "acceptedByUid", "acceptedByName", "leakTestReference",
    "ndtReference", "acceptanceNotes", "assuranceEpisodeId", "assuranceInvalidationReason",
    "assuranceInvalidatedByUid", "assuranceInvalidatedByName"]) {
    if ((profile[key] ?? null) !== (after[key] ?? null)) fail("The accepted cover evidence changed. Refresh before settling.");
  }
  if (instant(profile.acceptedAt) !== inspected ||
      (before.assuranceEpisodeId ?? requestId) !== after.assuranceEpisodeId) {
    fail("The acceptance does not belong to the current assurance episode.");
  }
  for (const key of ["assuranceInvalidatedAt", "assuranceInvalidatedRecordedAt"]) {
    if ((profile[key] == null ? null : instant(profile[key])) !==
        (after[key] == null ? null : instant(after[key])) ||
        (before[key] == null ? null : instant(before[key])) !==
        (after[key] == null ? null : instant(after[key]))) fail("The assurance episode evidence changed.");
  }
  for (const previous of [before.acceptedAt, before.assuranceInvalidatedAt]) {
    if (previous != null && inspected <= instant(previous)) fail("The inspection predates the current service event.");
  }
  return {acceptanceRequestId: requestId, acceptanceAuditId: id, acceptanceAuditSha256: hash,
    acceptanceReceiptSha256: digest({...receipt, committedAt: performed}),
    acceptanceProfileVersion: profile.version!, inspectedAt: inspected,
    acceptanceReference: after.acceptanceReference!, acceptedByUid: after.acceptedByUid!,
    assuranceEpisodeId: after.assuranceEpisodeId!};
}

/** Technical disposition is separate from administrative withdrawal and stock acceptance.
 * Only this retained case gains a settlement. No ticket, declaration or profile is erased.
 */
export const settleInnerCoverAssessment = async ({tx, command, context}: HandlerArgs): Promise<HandlerResult> => {
  validatePayload(command);
  if (!context.actor.roles.has("admin") && !context.actor.roles.has("si")) {
    throw new WorkflowError("permission-denied", "Only Admin or SI may settle this assessment.");
  }
  const [c, ticket, profile, occupied] = await Promise.all([
    load(tx, `furnace_stuckup_cases/${command.aggregateId}`),
    load(tx, `maintenance_records/${command.aggregateId}`),
    load(tx, `inner_cover_profiles/${command.payload.innerCoverId}`),
    tx.get(`audit_logs/server_asset_integrity_${command.commandId}`),
  ]);
  if (occupied.exists) fail("The assessment audit identity is already occupied.");
  validateOriginal(c, ticket, command);
  const at = iso(context.serverNow);
  if (instant(ticket.deletedAt) > at) fail("The recorded withdrawal time is in the future.");
  const [declaration, causeEvidence] = await Promise.all([
    load(tx, `asset_condition_declarations/${c.conditionDeclarationId}`),
    load(tx, `asset_condition_evidence/${c.conditionEvidenceId}`),
  ]);
  if (c.conditionDeclarationId !== `inner_cover_bulged_${c.innerCoverId}` ||
      c.conditionEvidenceId !== `${c.conditionDeclarationId}_${c.caseId}` ||
      declaration.schemaVersion !== 1 || declaration.declarationId !== c.conditionDeclarationId ||
      declaration.assetId !== c.innerCoverId || declaration.assetType !== "innerCover" ||
      declaration.assetSerialNumber !== c.innerCoverSerialNumber || declaration.state !== "confirmed" ||
      causeEvidence.schemaVersion !== 1 || causeEvidence.evidenceId !== c.conditionEvidenceId ||
      causeEvidence.declarationId !== c.conditionDeclarationId || causeEvidence.caseId !== c.caseId ||
      causeEvidence.ticketId !== c.ticketId || causeEvidence.confirmedCause !== c.confirmedCause ||
      causeEvidence.evidenceType !== "confirmedFurnaceStuckupCause" ||
      instant(causeEvidence.observedAt) !== instant(c.reportedAt) ||
      instant(causeEvidence.confirmedAt) !== instant(c.adjudicatedAt) ||
      causeEvidence.confirmedByUid !== c.adjudicatedByUid) {
    fail("The original confirmed-cause evidence is incomplete. Reconcile it before settling this concern.");
  }
  const withdrawal = await withdrawalProof(tx, ticket);
  const acceptance = await acceptanceProof(tx, c, profile, command, at);
  const disposition: JsonMap = {schemaVersion: 1, kind: "postEventInspectionAccepted",
    caseId: c.caseId!, ticketId: c.ticketId!, innerCoverId: c.innerCoverId!,
    innerCoverSerialNumber: c.innerCoverSerialNumber!, eventLinkageId: c.innerCoverLinkageId!,
    originalCaseVersion: c.version!, withdrawnTicketVersion: ticket.version!,
    ...withdrawal, ...acceptance, reason: (command.payload.reason as string).trim(),
    assessorConfirmed: true, settledAt: at, settledByUid: context.actor.uid,
    settledByName: context.actor.name, commandId: command.commandId};
  const update: JsonMap = {concernDisposition: disposition, updatedAt: at, version: command.expectedVersion + 1};
  const id = `server_asset_integrity_${command.commandId}`;
  const audit: JsonMap = {schemaVersion: 2, auditId: id, entityType: "furnaceStuckupCase",
    entityId: command.aggregateId, action: "update", operation: command.commandType,
    performedByUid: context.actor.uid, performedByName: context.actor.name, timestamp: at,
    requestId: command.commandId, commandFingerprint: payloadFingerprint(command as unknown as JsonMap),
    beforeJson: JSON.stringify(c), afterJson: JSON.stringify({...c, ...update}),
    resultVersion: update.version!};
  tx.create(`audit_logs/${id}`, audit);
  tx.update(`furnace_stuckup_cases/${command.aggregateId}`, update);
  return {resultKey: "inner-cover-assessment-settled", aggregateVersion: update.version as number,
    result: {caseId: command.aggregateId, auditId: id, auditSchemaVersion: 2,
      auditFingerprint: payloadFingerprint(audit)}};
};

export const verifyInnerCoverAssessmentReplay = async (args: {
  tx: WorkflowTransaction; command: WorkflowCommand; actor: Actor; receipt: WorkflowCommandReceipt;
}): Promise<void> => {
  const {tx, command, actor, receipt} = args;
  if (command.commandType !== "settleInnerCoverAssessment") return;
  validatePayload(command);
  const id = `server_asset_integrity_${command.commandId}`;
  const audit = await load(tx, `audit_logs/${id}`);
  const before = parsed(audit.beforeJson);
  const after = parsed(audit.afterJson);
  const current = await load(tx, `furnace_stuckup_cases/${command.aggregateId}`);
  const disposition = object(after.concernDisposition);
  const at = instant(audit.timestamp);
  if (audit.schemaVersion !== 2 || audit.auditId !== id || audit.operation !== command.commandType ||
      audit.entityType !== "furnaceStuckupCase" || audit.entityId !== command.aggregateId ||
      audit.action !== "update" || audit.performedByUid !== actor.uid ||
      audit.requestId !== command.commandId || audit.resultVersion !== receipt.aggregateVersion ||
      audit.commandFingerprint !== payloadFingerprint(command as unknown as JsonMap) ||
      receipt.commandId !== command.commandId || receipt.appliedAt !== at ||
      receipt.resultKey !== "inner-cover-assessment-settled" ||
      receipt.aggregateVersion !== command.expectedVersion + 1 ||
      stableJson(receipt.result) !== stableJson({caseId: command.aggregateId, auditId: id,
        auditSchemaVersion: 2, auditFingerprint: payloadFingerprint({...audit, timestamp: at})}) ||
      before.version !== command.expectedVersion || before.concernDisposition != null ||
      after.version !== receipt.aggregateVersion || !positive(current.version) ||
      current.version < receipt.aggregateVersion ||
      IDENTITY.some((key) => before[key] == null || before[key] !== after[key] || before[key] !== current[key]) ||
      disposition.commandId !== command.commandId || disposition.settledByUid !== actor.uid ||
      disposition.reason !== (command.payload.reason as string).trim() ||
      disposition.assessorConfirmed !== true || disposition.settledAt !== at ||
      stableJson(canonicalDisposition(current.concernDisposition)) !== stableJson(canonicalDisposition(disposition)) ||
      stableJson(after) !== stableJson({...before, concernDisposition: disposition,
        updatedAt: at, version: receipt.aggregateVersion})) fail("The settlement receipt no longer matches its immutable evidence.");
  const [acceptance, acceptanceReceipt, withdrawal, withdrawalReceipt] = await Promise.all([
    load(tx, `inner_cover_lifecycle_audits/${disposition.acceptanceAuditId}`),
    load(tx, `inner_cover_lifecycle_receipts/${disposition.acceptanceRequestId}`),
    load(tx, `audit_logs/${disposition.withdrawalAuditId}`),
    load(tx, `maintenance_workflow_command_receipts/${disposition.withdrawalRequestId}`),
  ]);
  if (auditHash(acceptance, "performedAt") !== disposition.acceptanceAuditSha256 ||
      digest({...acceptanceReceipt, committedAt: instant(acceptanceReceipt.committedAt)}) !== disposition.acceptanceReceiptSha256 ||
      auditHash(withdrawal, "timestamp") !== disposition.withdrawalAuditSha256 ||
      digest(withdrawalReceipt) !== disposition.withdrawalReceiptSha256) {
    fail("The settlement's retained inspection or withdrawal evidence changed. Reconciliation is required.");
  }
};
