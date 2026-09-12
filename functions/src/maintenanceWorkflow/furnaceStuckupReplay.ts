import {WorkflowError} from "./errors";
import {WorkflowTransaction} from "./store";
import {Actor, JsonMap, WorkflowCommand, WorkflowCommandReceipt} from "./types";
import {payloadFingerprint, persistedInstantText, stableJson} from "./utils";

const invalid = (): never => {
  throw new WorkflowError(
    "failed-precondition",
    "Furnace stuck-up receipt no longer matches its governed evidence. Reconciliation is required.",
    {reasonCode: "furnace-stuckup-replay-evidence-invalid"},
  );
};

const parsedObject = (value: unknown): JsonMap | null => {
  if (typeof value !== "string") return null;
  try {
    const decoded: unknown = JSON.parse(value);
    return decoded != null && typeof decoded === "object" &&
      !Array.isArray(decoded) ? decoded as JsonMap : null;
  } catch {
    return null;
  }
};

// Server-generated action times have millisecond precision. Do not hide a
// corrupted Timestamp's fractional milliseconds by rounding during comparison.
const instant = (value: unknown): string | null => {
  if (value != null && typeof value === "object" && !(value instanceof Date)) {
    const nanos = (value as {_nanoseconds?: unknown})._nanoseconds;
    if (typeof nanos !== "number" || nanos % 1_000_000 !== 0) return null;
  }
  return persistedInstantText(value);
};

const version = (value: unknown): value is number =>
  Number.isSafeInteger(value) && (value as number) >= 1;

const text = (value: unknown): value is string =>
  typeof value === "string" && value.trim().length > 0;

const CASE_IDENTITIES = [
  "caseId", "ticketId", "baseAssetClassId", "baseAssetInstanceId",
  "baseAssetNumber", "furnaceAssetClassId", "furnaceAssetInstanceId",
  "furnaceAssetNumber", "innerCoverId", "innerCoverSerialNumber",
  "innerCoverLinkageId", "innerCoverAssignmentVersion", "reportedByUid",
] as const;

/** Receipt replay proves the original transition, not the current lifecycle tip.
 * The dispatcher has already checked receipt ownership, authority and the full
 * original command fingerprint. Legacy audits are read, never rewritten.
 */
export const verifyFurnaceStuckupAudit = async (args: {
  tx: WorkflowTransaction;
  command: WorkflowCommand;
  actor: Actor;
  receipt: WorkflowCommandReceipt;
}): Promise<void> => {
  const {command, receipt, actor, tx} = args;
  const release = command.commandType === "releaseFurnaceStuckup";
  if (!release && command.commandType !== "adjudicateFurnaceStuckup") return;
  const id = `server_asset_integrity_${command.commandId}`;
  const [audit, current] = await Promise.all([
    tx.get(`audit_logs/${id}`),
    tx.get(`furnace_stuckup_cases/${command.aggregateId}`),
  ]);
  const data = audit.data;
  const before = parsedObject(data?.beforeJson);
  const after = parsedObject(data?.afterJson);
  if (!audit.exists || data == null || before == null || after == null ||
      !current.exists || current.data == null) invalid();
  const auditData = data!;
  const original = before!;
  const outcome = after!;
  const live = current.data!;
  const at = receipt.appliedAt;
  if (![1, 2].includes(auditData.schemaVersion as number) ||
      auditData.auditId !== id || auditData.entityType !== "furnaceStuckupCase" ||
      auditData.entityId !== command.aggregateId || auditData.action !== "update" ||
      auditData.operation !== command.commandType ||
      auditData.performedByUid !== actor.uid || !text(auditData.performedByName) ||
      auditData.requestId !== command.commandId ||
      auditData.resultVersion !== receipt.aggregateVersion ||
      instant(auditData.timestamp) !== at || instant(at) !== at ||
      receipt.commandId !== command.commandId ||
      receipt.aggregateVersion !== command.expectedVersion + 1 ||
      receipt.result.auditId !== id || receipt.result.caseId !== command.aggregateId ||
      receipt.resultKey !== (release ? "furnace-stuckup-released" : "furnace-stuckup-adjudicated") ||
      original.schemaVersion !== 1 || outcome.schemaVersion !== 1 || live.schemaVersion !== 1 ||
      original.caseId !== command.aggregateId || original.ticketId !== command.aggregateId ||
      original.version !== command.expectedVersion || !version(original.version) ||
      outcome.version !== receipt.aggregateVersion || !version(live.version) ||
      live.version < receipt.aggregateVersion ||
      CASE_IDENTITIES.some((key) => original[key] == null ||
        original[key] !== outcome[key] || original[key] !== live[key]) ||
      instant(original.reportedAt) == null ||
      instant(original.reportedAt) !== instant(outcome.reportedAt) ||
      instant(original.reportedAt) !== instant(live.reportedAt)) invalid();

  const modern = auditData.schemaVersion === 2 ||
    auditData.commandFingerprint != null || receipt.result.auditSchemaVersion != null ||
    receipt.result.auditFingerprint != null;
  if (modern && (auditData.schemaVersion !== 2 || receipt.result.auditSchemaVersion !== 2 ||
      auditData.commandFingerprint !== payloadFingerprint(command as unknown as JsonMap) ||
      receipt.result.auditFingerprint !== payloadFingerprint({...auditData, timestamp: at}))) invalid();

  let expectedUpdate: JsonMap;
  let expectedResult: JsonMap = {caseId: command.aggregateId, auditId: id};
  const name = auditData.performedByName;
  if (release) {
    if (original.obstructionStatus !== "active" || !text(command.payload.releaseNotes)) invalid();
    expectedUpdate = {
      obstructionStatus: "released", releasedAt: at, releasedByUid: actor.uid,
      releasedByName: name, releaseNotes: (command.payload.releaseNotes as string).trim(),
      updatedAt: at, version: receipt.aggregateVersion,
    };
    for (const assetId of [original.baseAssetInstanceId, original.furnaceAssetInstanceId]) {
      const constraintId = `${command.aggregateId}_${assetId}`;
      const constraint = await tx.get(`asset_availability_constraints/${constraintId}`);
      const row = constraint.data;
      if (!constraint.exists || row == null || row.schemaVersion !== 1 ||
          row.constraintId !== constraintId || row.caseId !== command.aggregateId ||
          row.assetInstanceId !== assetId || row.status !== "released" ||
          !version(row.version) || row.version < 2 ||
          instant(row.releasedAt) !== at || row.releasedByUid !== actor.uid ||
          row.releasedByName !== name) invalid();
    }
  } else {
    const cause = command.payload.confirmedCause;
    if (original.adjudicationStatus !== "pending" || !text(cause) ||
        !["innerCoverBulging", "draftSealPlateDamagedOrFallen", "insufficientDraftSealClearance",
          "combinedCondition", "other", "inconclusive"].includes(cause.trim()) ||
        !text(command.payload.adjudicationNotes)) invalid();
    const normalizedCause = (cause as string).trim();
    const bulging = normalizedCause === "innerCoverBulging" || normalizedCause === "combinedCondition";
    const declarationId = bulging ? `inner_cover_bulged_${original.innerCoverId}` : null;
    const evidenceId = bulging ? `${declarationId}_${command.aggregateId}` : null;
    const notes = (command.payload.adjudicationNotes as string).trim();
    expectedUpdate = {
      adjudicationStatus: normalizedCause === "inconclusive" ? "inconclusive" : "confirmed",
      confirmedCause: normalizedCause, adjudicationNotes: notes, adjudicatedAt: at,
      adjudicatedByUid: actor.uid, adjudicatedByName: name,
      conditionDeclarationId: declarationId, conditionEvidenceId: evidenceId,
      updatedAt: at, version: receipt.aggregateVersion,
    };
    expectedResult = {...expectedResult, declarationId, evidenceId};
    if (bulging) {
      const [evidence, declaration] = await Promise.all([
        tx.get(`asset_condition_evidence/${evidenceId}`),
        tx.get(`asset_condition_declarations/${declarationId}`),
      ]);
      const row = evidence.data;
      const declared = declaration.data;
      if (!evidence.exists || row == null || row.schemaVersion !== 1 ||
          row.evidenceId !== evidenceId || row.declarationId !== declarationId ||
          row.caseId !== command.aggregateId || row.ticketId !== command.aggregateId ||
          row.evidenceType !== "confirmedFurnaceStuckupCause" ||
          row.confirmedCause !== normalizedCause || row.notes !== notes ||
          instant(row.observedAt) !== instant(original.reportedAt) ||
          instant(row.confirmedAt) !== at || row.confirmedByUid !== actor.uid ||
          row.confirmedByName !== name || !declaration.exists || declared == null ||
          declared.schemaVersion !== 1 || declared.declarationId !== declarationId ||
          declared.assetId !== original.innerCoverId || declared.assetType !== "innerCover" ||
          declared.assetSerialNumber !== original.innerCoverSerialNumber ||
          declared.conditionType !== "innerCoverBulged" || !version(declared.version)) invalid();
    }
  }
  if (stableJson(outcome) !== stableJson({...original, ...expectedUpdate})) invalid();
  if (modern) expectedResult = {
    ...expectedResult, auditSchemaVersion: 2, auditFingerprint: receipt.result.auditFingerprint,
  };
  if (stableJson(receipt.result) !== stableJson(expectedResult)) invalid();
};
