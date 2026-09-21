import {
  UV_DETECTOR_CORRECTIONS,
  applyUvDetectorInstallationCorrection,
  prepareUvDetectorInstallationCorrection,
  canonicalUvCorrectionInstant,
} from "./uvDetectorCorrection";
import {WorkflowError} from "./errors";
import {CommandHandler} from "./handlerTypes";
import {Actor, JsonMap, WorkflowCommand, WorkflowCommandReceipt} from "./types";
import {WorkflowTransaction} from "./store";
import {cleanText, iso, payloadFingerprint, stableJson} from "./utils";

const correctionPath = (correctionId: string): string =>
  `${UV_DETECTOR_CORRECTIONS}/${correctionId}`;
const auditId = (commandId: string): string =>
  `server_uv_detector_correction_${commandId}`;
const auditPath = (commandId: string): string =>
  `audit_logs/${auditId(commandId)}`;

const samePersistedInstant = (left: unknown, right: unknown): boolean => {
  const leftInstant = canonicalUvCorrectionInstant(left);
  return leftInstant != null && leftInstant === canonicalUvCorrectionInstant(right);
};

const canonicalInstant = canonicalUvCorrectionInstant;

const correctionEvidence = (value: unknown): JsonMap | null => {
  if (value == null || typeof value !== "object" || Array.isArray(value)) return null;
  const result = {...value as JsonMap};
  for (const field of ["recordedActionPerformedAt", "correctedActionPerformedAt", "correctedAt", "expectedCurrentActionPerformedAt"]) {
    const instant = canonicalInstant(result[field]);
    if (instant == null) return null;
    result[field] = instant;
  }
  return result;
};

const acceptedCorrectionEvidence = (audit: JsonMap): JsonMap | null => {
  if (typeof audit.afterJson !== "string") return null;
  try {
    const after = JSON.parse(audit.afterJson) as unknown;
    if (after == null || typeof after !== "object" || Array.isArray(after)) return null;
    return correctionEvidence((after as JsonMap).correction);
  } catch (_) {
    return null;
  }
};

const acceptedResult = (audit: JsonMap, command: WorkflowCommand): JsonMap | null => {
  try {
    const after = JSON.parse(audit.afterJson as string) as JsonMap;
    const correction = correctionEvidence(after.correction);
    const current = after.currentInstallation as JsonMap;
    if (correction == null || current == null ||
        canonicalInstant(current.actionPerformedAt) == null) return null;
    return {
      correctionId: command.aggregateId,
      correctsEventId: correction.correctsEventId,
      expectedCurrentEventId: correction.expectedCurrentEventId,
      expectedCurrentActionPerformedAt: correction.expectedCurrentActionPerformedAt,
      supersedesCorrectionId: correction.supersedesCorrectionId,
      assetInstanceId: correction.assetInstanceId,
      burnerPosition: correction.burnerPosition,
      recordedActionPerformedAt: correction.recordedActionPerformedAt,
      correctedActionPerformedAt: correction.correctedActionPerformedAt,
      currentEventId: current.currentEventId,
      currentActionPerformedAt: canonicalInstant(current.actionPerformedAt),
      auditId: auditId(command.commandId),
      auditSchemaVersion: 2,
      auditFingerprint: payloadFingerprint({...audit, timestamp: canonicalInstant(audit.timestamp)}),
    };
  } catch (_) {
    return null;
  }
};

const normalizedResult = (result: JsonMap): JsonMap | null => {
  const normalized = {...result};
  for (const field of ["expectedCurrentActionPerformedAt", "recordedActionPerformedAt",
    "correctedActionPerformedAt", "currentActionPerformedAt"]) {
    const instant = canonicalInstant(normalized[field]);
    if (instant == null) return null;
    normalized[field] = instant;
  }
  return normalized;
};

const exactKeys = (
  value: JsonMap,
  expected: readonly string[],
  field: string,
): void => {
  if (Object.keys(value).sort().join(",") !== [...expected].sort().join(",")) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} has unsupported or missing fields.`,
      {reasonCode: "uv-detector-correction-command-shape-invalid", field},
    );
  }
};

const documentId = (value: unknown, field: string): string => {
  const parsed = cleanText(value, field);
  if (parsed.length > 160 || parsed === "." || parsed === ".." ||
      parsed.includes("/")) {
    throw new WorkflowError("invalid-argument", `${field} is invalid.`);
  }
  return parsed;
};

/**
 * Putting right an installation time that was written down wrong.
 *
 * The plant records a UV detector replacement when the job closes, and the
 * date it carries is the date somebody entered. When that date is wrong, the
 * two obvious repairs are wrong with it: recording a second replacement
 * invents a physical event that never happened, and editing the original
 * destroys what the person actually wrote. So this is its own separately
 * authorized command, held at the authority that adjudicates a disputed
 * physical condition, and what it writes is a successor record that names the
 * event it corrects and says why.
 *
 * The original stays exactly as recorded. What the position says is installed
 * now is rebuilt from the evidence that survives - which is the part an
 * ordinary replacement cannot do, because a corrected date can move the
 * current installation backwards to an earlier replacement.
 */
export const correctUvDetectorInstallation: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(
    command.payload,
    [
      "eventId",
      "expectedCurrentEventId",
      "expectedCurrentActionPerformedAt",
      "correctedActionPerformedAt",
      "reason",
      "supersedesCorrectionId",
    ],
    "payload",
  );
  if (command.expectedVersion !== 0) {
    throw new WorkflowError(
      "failed-precondition",
      "A correction is a new record, not an edit of the original.",
      {reasonCode: "uv-detector-correction-expected-version-invalid"},
    );
  }
  const correctionId = documentId(command.aggregateId, "aggregateId");
  const eventId = documentId(command.payload.eventId, "eventId");
  const expectedCurrentEventId = documentId(
    command.payload.expectedCurrentEventId,
    "expectedCurrentEventId",
  );
  const supersedesCorrectionId = command.payload.supersedesCorrectionId == null ?
    null :
    documentId(command.payload.supersedesCorrectionId, "supersedesCorrectionId");
  if (correctionId === supersedesCorrectionId) {
    throw new WorkflowError(
      "invalid-argument",
      "A correction cannot supersede itself.",
      {reasonCode: "uv-detector-correction-identity-collides"},
    );
  }
  const correctedActionPerformedAt = cleanText(
    command.payload.correctedActionPerformedAt,
    "correctedActionPerformedAt",
  );
  const parsed = new Date(correctedActionPerformedAt);
  if (canonicalInstant(correctedActionPerformedAt) == null) {
    throw new WorkflowError(
      "invalid-argument",
      "correctedActionPerformedAt is invalid.",
    );
  }
  if (parsed.getTime() > context.serverNow.getTime()) {
    throw new WorkflowError(
      "invalid-argument",
      "A corrected installation time cannot be later than the correction time.",
      {reasonCode: "uv-detector-correction-future-dated"},
    );
  }

  const existing = await tx.get(correctionPath(correctionId));
  if (existing.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "A uv-detector correction already holds that identity.",
      {reasonCode: "uv-detector-correction-identity-taken"},
    );
  }

  const plan = await prepareUvDetectorInstallationCorrection({
    tx,
    eventId,
    expectedCurrentEventId,
    expectedCurrentActionPerformedAt: cleanText(
      command.payload.expectedCurrentActionPerformedAt,
      "expectedCurrentActionPerformedAt",
    ),
    correctedActionPerformedAt,
    reason: command.payload.reason,
    supersedesCorrectionId,
    correctedBy: {uid: context.actor.uid, name: context.actor.name},
    correctedAt: iso(context.serverNow),
    correctionId,
  });
  applyUvDetectorInstallationCorrection(tx, plan);

  const audit: JsonMap = {
    schemaVersion: 2,
    auditId: auditId(command.commandId),
    entityType: "uvDetectorInstallationCorrection",
    entityId: correctionId,
    action: "update",
    operation: command.commandType,
    performedByUid: context.actor.uid,
    performedByName: context.actor.name,
    timestamp: iso(context.serverNow),
    reason: "correction",
    reasonNotes: plan.correction.data.reason,
    summary: "UV detector installation time corrected",
    severity: "medium",
    // Both halves of the change are here: the event whose recorded time was
    // wrong, together with the correction it already carried if any, and what
    // the position now says is installed. A reader shown only the new record
    // could not tell whether the current installation moved.
    beforeJson: stableJson({
      correctedEvent: plan.correctedEvent,
      correctionInForce: plan.supersededCorrection ?? {},
      currentInstallation: plan.previousCurrentState ?? {},
    }),
    afterJson: stableJson({
      correction: plan.correction.data,
      currentInstallation: plan.currentState.data,
    }),
    requestId: command.commandId,
    resultVersion: 1,
    commandFingerprint: payloadFingerprint(command as unknown as JsonMap),
  };
  tx.create(auditPath(command.commandId), audit);

  return {
    resultKey: "uv-detector-installation-corrected",
    aggregateVersion: 1,
    result: {
      correctionId,
      correctsEventId: eventId,
      expectedCurrentEventId,
      expectedCurrentActionPerformedAt: plan.correction.data.expectedCurrentActionPerformedAt,
      supersedesCorrectionId,
      assetInstanceId: plan.correction.data.assetInstanceId ?? null,
      burnerPosition: plan.correction.data.burnerPosition ?? null,
      recordedActionPerformedAt:
        plan.correction.data.recordedActionPerformedAt ?? null,
      correctedActionPerformedAt:
        plan.correction.data.correctedActionPerformedAt ?? null,
      currentEventId: plan.currentState.data.currentEventId ?? null,
      currentActionPerformedAt: plan.currentState.data.actionPerformedAt ?? null,
      auditId: auditId(command.commandId),
      auditSchemaVersion: 2,
      auditFingerprint: payloadFingerprint(audit),
    },
  };
};

/**
 * A replay confirms what was accepted; it cannot stand in for evidence that
 * has gone. If the correction or its audit is no longer there, the honest
 * answer is that this outcome can no longer be shown - not a second report of
 * success over an empty record.
 */
export const verifyUvDetectorCorrectionReplay = async (args: {
  readonly tx: WorkflowTransaction;
  readonly command: WorkflowCommand;
  readonly actor: Actor;
  readonly receipt: WorkflowCommandReceipt;
}): Promise<void> => {
  if (args.command.commandType !== "correctUvDetectorInstallation") return;
  const [correction, audit] = await Promise.all([
    args.tx.get(correctionPath(args.command.aggregateId)),
    args.tx.get(auditPath(args.command.commandId)),
  ]);
  const data = audit.data;
  const auditTimestamp = data == null ? null : canonicalInstant(data.timestamp);
  const acceptedCorrection = data == null ? null : acceptedCorrectionEvidence(data);
  const retainedCorrection = correctionEvidence(correction.data);
  const expectedResult = data == null ? null : acceptedResult(data, args.command);
  const receiptResult = normalizedResult(args.receipt.result);
  if (!correction.exists || correction.data == null || !audit.exists ||
      data == null ||
      args.receipt.aggregateVersion !== 1 ||
      args.receipt.appliedAt !== auditTimestamp ||
      args.receipt.resultKey !== "uv-detector-installation-corrected" ||
      args.receipt.result.correctionId !== args.command.aggregateId ||
      correction.data.correctsEventId !== args.receipt.result.correctsEventId ||
      correction.data.expectedCurrentEventId !==
        args.receipt.result.expectedCurrentEventId ||
      !samePersistedInstant(
        correction.data.correctedActionPerformedAt,
        args.receipt.result.correctedActionPerformedAt,
      ) ||
      data.schemaVersion !== 2 ||
      data.auditId !== auditId(args.command.commandId) ||
      args.receipt.result.auditId !== data.auditId ||
      args.receipt.result.auditSchemaVersion !== data.schemaVersion ||
      data.entityId !== args.command.aggregateId ||
      data.entityType !== "uvDetectorInstallationCorrection" ||
      data.operation !== args.command.commandType ||
      data.requestId !== args.command.commandId ||
      data.resultVersion !== 1 ||
      data.performedByUid !== args.actor.uid ||
      data.commandFingerprint !== payloadFingerprint(args.command as unknown as JsonMap) ||
      auditTimestamp == null ||
      // Existing schema-2 receipts already bind the accepted audit. Check that
      // original binding rather than minting fresh evidence from today's data.
      args.receipt.result.auditFingerprint !== payloadFingerprint({...data, timestamp: auditTimestamp}) ||
      acceptedCorrection == null || retainedCorrection == null ||
      expectedResult == null || receiptResult == null ||
      stableJson(expectedResult) !== stableJson(receiptResult) ||
      stableJson(acceptedCorrection) !== stableJson(retainedCorrection)) {
    throw new WorkflowError(
      "failed-precondition",
      "UV-detector correction replay evidence is missing or inconsistent.",
      {reasonCode: "uv-detector-correction-replay-invalid"},
    );
  }
};
