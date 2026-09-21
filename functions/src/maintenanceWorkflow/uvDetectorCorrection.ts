import {createHash} from "crypto";
import {persistedInstantMillis} from "../persistedInstant";
import {WorkflowError} from "./errors";
import {WorkflowTransaction} from "./store";
import {JsonMap} from "./types";

const requiredText = (value: unknown, field: string): string => {
  if (typeof value !== "string" || value.trim().length === 0 || value.length > 1000) {
    throw new WorkflowError("failed-precondition", `UV correction ${field} is invalid.`,
      {reasonCode: "uv-detector-correction-evidence-invalid", field});
  }
  return value.trim();
};
const positiveInteger = (value: unknown, field: string): number => {
  if (!Number.isSafeInteger(value) || (value as number) < 1 || (value as number) > 8) {
    throw new WorkflowError("failed-precondition", `UV correction ${field} is invalid.`,
      {reasonCode: "uv-detector-correction-evidence-invalid", field});
  }
  return value as number;
};

// New correction evidence is emitted at whole-millisecond precision. Refuse
// lossy timestamp normalization, including native Firestore sub-milliseconds.
export const canonicalUvCorrectionInstant = (value: unknown): string | null => {
  if (value != null && typeof value === "object" && !(value instanceof Date)) {
    const stamp = value as Record<string, unknown>;
    const nanos = stamp.nanoseconds ?? stamp._nanoseconds;
    if (!Number.isSafeInteger(nanos) || (nanos as number) % 1000000 !== 0) return null;
  }
  const millis = persistedInstantMillis(value);
  if (!Number.isSafeInteger(millis)) return null;
  const iso = new Date(millis).toISOString();
  if (typeof value === "string" && value !== iso) return null;
  return iso;
};
const parseInstant = (value: unknown, field: string): string => {
  const result = canonicalUvCorrectionInstant(value);
  if (result == null) throw new WorkflowError("failed-precondition",
    `UV correction ${field} is not an exact installation instant.`,
    {reasonCode: "uv-detector-correction-evidence-invalid", field});
  return result;
};
const currentStateId = (assetInstanceId: string, burnerPosition: number): string =>
  `uvlc_${createHash("sha256").update(`${assetInstanceId}|${burnerPosition}`, "utf8")
    .digest("hex").slice(0, 40)}`;
const isLaterLifecycleData = (candidate: JsonMap, current: JsonMap): boolean => {
  for (const field of ["actionPerformedAt", "recordedAt"]) {
    const left = parseInstant(candidate[field], field);
    const right = parseInstant(current[field], field);
    if (left !== right) return left > right;
  }
  return requiredText(candidate.eventId, "eventId") > requiredText(current.eventId, "eventId");
};

export const UV_DETECTOR_CORRECTIONS =
  "uv_detector_lifecycle_corrections";

export interface UvDetectorCorrectionWritePlan {
  readonly correction: {readonly path: string; readonly data: JsonMap};
  readonly currentState: {readonly path: string; readonly data: JsonMap};
  readonly correctedEvent: JsonMap;
  readonly supersededCorrection: JsonMap | null;
  readonly previousCurrentState: JsonMap | null;
}

const requireCurrentProjection = async (args: {
  readonly tx: WorkflowTransaction;
  readonly assetInstanceId: string;
  readonly burnerPosition: number;
  readonly expectedCurrentEventId: string;
  readonly expectedCurrentActionPerformedAt: string;
}): Promise<{
  readonly projectionId: string;
  readonly snapshot: Awaited<ReturnType<WorkflowTransaction["get"]>>;
}> => {
  const projectionId = currentStateId(
    args.assetInstanceId,
    args.burnerPosition,
  );
  const snapshot = await args.tx.get(
    `uv_detector_lifecycle_current/${projectionId}`,
  );
  const data = snapshot.data;
  if (!snapshot.exists || data == null ||
      data.projectionSchemaVersion !== 1 ||
      data.projectionId !== projectionId ||
      data.currentEventId !== data.eventId ||
      data.assetInstanceId !== args.assetInstanceId ||
      data.burnerPosition !== args.burnerPosition ||
      data.installationDiscipline !== "instrumentation" ||
      data.resultingCondition !== "serviceable") {
    throw new WorkflowError(
      "failed-precondition",
      "The current uv-detector lifecycle projection is missing or inconsistent.",
      {reasonCode: "uv-detector-lifecycle-current-invalid", projectionId},
    );
  }
  if (data.currentEventId !== args.expectedCurrentEventId ||
      parseInstant(data.actionPerformedAt, "current.actionPerformedAt") !==
        parseInstant(args.expectedCurrentActionPerformedAt, "expectedCurrentActionPerformedAt")) {
    throw new WorkflowError(
      "workflow-version-conflict",
      "The uv-detector installation changed before this correction was applied.",
      {
        reasonCode: "uv-detector-lifecycle-current-version-conflict",
        projectionId,
        expectedCurrentEventId: args.expectedCurrentEventId,
        actualCurrentEventId: data.currentEventId,
      },
    );
  }
  return {projectionId, snapshot};
};

/** The correction in force for an event: the one nothing else supersedes. */
const effectiveCorrection = (
  corrections: readonly JsonMap[],
  eventId: string,
): JsonMap | null => {
  const superseded = new Set(
    corrections
      .map((data) => data.supersedesCorrectionId)
      .filter((value): value is string => typeof value === "string"),
  );
  const live = corrections.filter((data) =>
    data.correctsEventId === eventId &&
    !superseded.has(String(data.correctionId)));
  if (live.length > 1) {
    throw new WorkflowError(
      "failed-precondition",
      "This installation has more than one correction in force.",
      {reasonCode: "uv-detector-lifecycle-corrections-conflict", eventId},
    );
  }
  return live[0] ?? null;
};

/** What an event says now: its own time, or the time a correction gave it. */
const correctedInstallationTime = (
  event: JsonMap,
  corrections: readonly JsonMap[],
): string => {
  const correction = effectiveCorrection(
    corrections,
    requiredText(event.eventId, "current.eventId"),
  );
  return parseInstant(
    correction == null ?
      event.actionPerformedAt : correction.correctedActionPerformedAt,
    "current.actionPerformedAt",
  );
};

const validateHistory = (
  events: readonly JsonMap[], corrections: readonly JsonMap[],
  assetInstanceId: string, burnerPosition: number, assetClassId: unknown,
): void => {
  const invalid = (): never => {
    throw new WorkflowError("failed-precondition",
      "The retained UV installation history requires reviewed repair before correction.",
      {reasonCode: "uv-detector-correction-history-invalid"});
  };
  const byEvent = new Map<string, JsonMap>();
  for (const event of events) {
    const id = requiredText(event.eventId, "eventId");
    if (byEvent.has(id) || event.schemaVersion !== 1 || event.version !== 1 ||
        event.eventType !== "replacement" || event.isDeleted !== false ||
        event.assetInstanceId !== assetInstanceId || event.assetClassId !== assetClassId ||
        event.burnerPosition !== burnerPosition ||
        event.resultingCondition !== "serviceable" ||
        event.installationDiscipline !== "instrumentation" ||
        !["newPart", "repaired", "revised"].includes(String(event.replacementDisposition)) ||
        Date.parse(parseInstant(event.actionPerformedAt, "actionPerformedAt")) >
          Date.parse(parseInstant(event.completedAt, "completedAt")) + 300000 ||
        Date.parse(parseInstant(event.completedAt, "completedAt")) !==
          Date.parse(parseInstant(event.recordedAt, "recordedAt"))) invalid();
    byEvent.set(id, event);
  }
  const byId = new Map<string, JsonMap>();
  for (const correction of corrections) {
    const id = requiredText(correction.correctionId, "correctionId");
    const event = byEvent.get(String(correction.correctsEventId));
    if (event == null || byId.has(id) || correction.schemaVersion !== 1 ||
        correction.version !== 1 || correction.assetInstanceId !== assetInstanceId ||
        correction.assetClassId !== assetClassId || correction.burnerPosition !== burnerPosition ||
        correction.assetNumber !== event.assetNumber || correction.componentTag !== event.componentTag ||
        !byEvent.has(String(correction.expectedCurrentEventId)) ||
        parseInstant(correction.recordedActionPerformedAt, "recordedActionPerformedAt") !==
          parseInstant(event.actionPerformedAt, "actionPerformedAt") ||
        Date.parse(parseInstant(correction.correctedActionPerformedAt, "correctedActionPerformedAt")) >
          Date.parse(parseInstant(correction.correctedAt, "correctedAt")) ||
        Date.parse(parseInstant(correction.correctedActionPerformedAt, "correctedActionPerformedAt")) >
          Date.parse(parseInstant(event.completedAt, "completedAt")) + 300000) invalid();
    requiredText(correction.correctedByUid, "correctedByUid");
    requiredText(correction.correctedByName, "correctedByName");
    requiredText(correction.reason, "reason");
    parseInstant(correction.expectedCurrentActionPerformedAt, "expectedCurrentActionPerformedAt");
    byId.set(id, correction);
  }
  const superseded = new Set<string>();
  for (const correction of corrections) {
    const predecessorId = correction.supersedesCorrectionId;
    if (predecessorId != null) {
      if (typeof predecessorId !== "string" || superseded.has(predecessorId)) invalid();
      const predecessor = byId.get(predecessorId as string);
      if (predecessor == null || predecessor.correctsEventId !== correction.correctsEventId ||
          parseInstant(predecessor.correctedAt, "correctedAt") >
            parseInstant(correction.correctedAt, "correctedAt")) invalid();
      superseded.add(predecessorId as string);
    }
    const visited = new Set<string>();
    let cursor: JsonMap | undefined = correction;
    while (cursor != null) {
      const id = String(cursor.correctionId);
      if (visited.has(id)) invalid();
      visited.add(id);
      cursor = byId.get(String(cursor.supersedesCorrectionId));
    }
  }
  for (const eventId of byEvent.keys()) effectiveCorrection(corrections, eventId);
};

/**
 * Putting right an installation time that was written down wrong.
 *
 * Neither obvious repair is honest. Recording another replacement invents a
 * physical event that never happened and adds one to the count of times that
 * position was changed; editing the original destroys what somebody actually
 * wrote. So a correction is neither: it is its own record, in its own
 * collection, naming the event it corrects and saying why.
 *
 * Keeping it out of the lifecycle event collection is deliberate. Installed
 * handsets read every document in that collection through a decoder that
 * refuses fields it does not know, so a correction filed there would have
 * darkened the whole uv-detector history on the plant rather than adding a
 * line to it. What those handsets do see is the rebuilt current installation,
 * which is the part that matters operationally.
 *
 * The rebuild is the reason this cannot reuse the ordinary write plan. That
 * plan only ever moves the current installation forward; a corrected date can
 * move it back, to an earlier replacement that was the true one all along.
 */
export const prepareUvDetectorInstallationCorrection = async (args: {
  readonly tx: WorkflowTransaction;
  readonly eventId: string;
  readonly expectedCurrentEventId: string;
  readonly expectedCurrentActionPerformedAt: string;
  readonly correctedActionPerformedAt: unknown;
  readonly reason: unknown;
  readonly supersedesCorrectionId: string | null;
  readonly correctedBy: {readonly uid: string | null; readonly name: string};
  readonly correctedAt: unknown;
  readonly correctionId: string;
}): Promise<UvDetectorCorrectionWritePlan> => {
  const reason = requiredText(args.reason, "reason");
  const correctedActionPerformedAt = parseInstant(
    args.correctedActionPerformedAt,
    "correctedActionPerformedAt",
  );
  const correctedAt = parseInstant(args.correctedAt, "correctedAt");
  if (Date.parse(correctedActionPerformedAt) > Date.parse(correctedAt)) {
    throw new WorkflowError(
      "failed-precondition",
      "A corrected installation time cannot be later than the correction time.",
      {reasonCode: "uv-detector-lifecycle-correction-chronology-invalid"},
    );
  }
  const original = await args.tx.get(
    `uv_detector_lifecycle_events/${args.eventId}`,
  );
  if (!original.exists || original.data == null ||
      original.data.isDeleted === true) {
    throw new WorkflowError(
      "failed-precondition",
      "That uv-detector lifecycle event was not found.",
      {
        reasonCode: "uv-detector-lifecycle-event-unknown",
        eventId: args.eventId,
      },
    );
  }
  const assetInstanceId = requiredText(
    original.data.assetInstanceId,
    "current.assetInstanceId",
  );
  const originalCompletedAt = parseInstant(
    original.data.completedAt,
    "current.completedAt",
  );
  if (correctedAt < parseInstant(original.data.recordedAt, "original.recordedAt")) {
    throw new WorkflowError("failed-precondition",
      "The correction cannot be recorded before its original installation evidence.",
      {reasonCode: "uv-detector-lifecycle-correction-chronology-invalid"});
  }
  // Installed clients still validate the shared current projection using the
  // raw event's closure chronology. Refuse a correction that would make that
  // projection unreadable; a mistaken closure needs a separately governed
  // correction rather than an incompatible shared record.
  if (Date.parse(correctedActionPerformedAt) >
      Date.parse(originalCompletedAt) + 5 * 60 * 1000) {
    throw new WorkflowError(
      "failed-precondition",
      "The corrected installation time would make the current projection incompatible with installed clients.",
      {reasonCode: "uv-detector-lifecycle-correction-after-completion"},
    );
  }
  const burnerPosition = positiveInteger(
    original.data.burnerPosition,
    "current.burnerPosition",
  );
  const current = await requireCurrentProjection({
    tx: args.tx,
    assetInstanceId,
    burnerPosition,
    expectedCurrentEventId: requiredText(
      args.expectedCurrentEventId,
      "expectedCurrentEventId",
    ),
    expectedCurrentActionPerformedAt: args.expectedCurrentActionPerformedAt,
  });
  const [siblings, storedCorrections] = await Promise.all([
    args.tx.query("uv_detector_lifecycle_events", [
      {field: "assetInstanceId", op: "==", value: assetInstanceId},
      {field: "burnerPosition", op: "==", value: burnerPosition},
    ]),
    args.tx.query(UV_DETECTOR_CORRECTIONS, [
      {field: "assetInstanceId", op: "==", value: assetInstanceId},
      {field: "burnerPosition", op: "==", value: burnerPosition},
    ]),
  ]);
  if (siblings.some((row) => row.data == null ||
      row.path !== `uv_detector_lifecycle_events/${row.data.eventId}`) ||
      storedCorrections.some((row) => row.data == null ||
        row.path !== `${UV_DETECTOR_CORRECTIONS}/${row.data.correctionId}`)) {
    throw new WorkflowError("failed-precondition", "UV installation history identity is inconsistent.",
      {reasonCode: "uv-detector-correction-history-invalid"});
  }
  const surviving = siblings
    .map((row) => row.data)
    .filter((data): data is JsonMap => data != null);
  const corrections = storedCorrections
    .map((row) => row.data)
    .filter((data): data is JsonMap => data != null);
  validateHistory(surviving, corrections, assetInstanceId, burnerPosition, original.data.assetClassId);
  if (!surviving.some((event) => event.eventId === args.eventId)) {
    throw new WorkflowError("failed-precondition", "The original UV event has inconsistent identity.",
      {reasonCode: "uv-detector-correction-history-invalid"});
  }
  let priorWinner: JsonMap | null = null;
  for (const event of surviving) {
    const effective = {...event, actionPerformedAt: correctedInstallationTime(event, corrections)};
    if (priorWinner == null || isLaterLifecycleData(effective, priorWinner)) priorWinner = effective;
  }
  if (priorWinner == null || priorWinner.eventId !== current.snapshot.data?.currentEventId ||
      priorWinner.actionPerformedAt !== parseInstant(current.snapshot.data?.actionPerformedAt, "current.actionPerformedAt")) {
    throw new WorkflowError("failed-precondition", "Current UV installation disagrees with retained history.",
      {reasonCode: "uv-detector-lifecycle-current-invalid"});
  }

  // A correction that is itself wrong is corrected in turn, but only by
  // somebody who knows what is in force. Naming the wrong predecessor - or
  // none at all - means the caller was looking at something else.
  const inForce = effectiveCorrection(corrections, args.eventId);
  const named = args.supersedesCorrectionId;
  if (inForce != null && correctedAt < parseInstant(inForce.correctedAt, "predecessor.correctedAt")) {
    throw new WorkflowError("failed-precondition",
      "The correction cannot precede the reviewed correction it supersedes.",
      {reasonCode: "uv-detector-lifecycle-correction-chronology-invalid"});
  }
  if ((inForce == null ? null : String(inForce.correctionId)) !== named) {
    throw new WorkflowError(
      "failed-precondition",
      inForce == null ?
        "That installation time has not been corrected before." :
        "This installation time has already been corrected. " +
          "Correct the correction that is in force.",
      {
        reasonCode: "uv-detector-lifecycle-correction-stale",
        eventId: args.eventId,
        correctionInForce: inForce == null ? null : inForce.correctionId,
      },
    );
  }
  if (correctedInstallationTime(original.data, corrections) ===
      correctedActionPerformedAt) {
    // Restating the time already in force corrects nothing, and the record it
    // would leave behind would claim a correction that never happened.
    throw new WorkflowError(
      "failed-precondition",
      "That is the installation time already in force for this event.",
      {
        reasonCode: "uv-detector-lifecycle-correction-no-change",
        eventId: args.eventId,
      },
    );
  }

  const correction: JsonMap = {
    schemaVersion: 1,
    correctionId: args.correctionId,
    correctsEventId: args.eventId,
    expectedCurrentEventId: args.expectedCurrentEventId,
    expectedCurrentActionPerformedAt: args.expectedCurrentActionPerformedAt,
    supersedesCorrectionId: named,
    assetInstanceId,
    burnerPosition,
    assetClassId: original.data.assetClassId ?? null,
    assetNumber: original.data.assetNumber ?? null,
    componentTag: original.data.componentTag ?? null,
    recordedActionPerformedAt: parseInstant(
      original.data.actionPerformedAt,
      "current.actionPerformedAt",
    ),
    correctedActionPerformedAt,
    reason,
    correctedAt,
    correctedByUid: args.correctedBy.uid,
    correctedByName: args.correctedBy.name,
    version: 1,
  };

  // Rebuilt from every surviving event at this position, each read at the
  // time in force for it, so the answer does not depend on which way the
  // corrected date moved.
  const effective = [...corrections, correction];
  let winner: JsonMap | null = null;
  for (const data of surviving) {
    const candidate: JsonMap = {
      ...data,
      actionPerformedAt: correctedInstallationTime(data, effective),
    };
    if (winner == null || isLaterLifecycleData(candidate, winner)) {
      winner = candidate;
    }
  }
  if (winner == null) {
    throw new WorkflowError(
      "failed-precondition",
      "Correcting this event would leave the position with no installation.",
      {reasonCode: "uv-detector-lifecycle-correction-empties-position"},
    );
  }
  return {
    correction: {
      path: `${UV_DETECTOR_CORRECTIONS}/${args.correctionId}`,
      data: correction,
    },
    currentState: {
      path: `uv_detector_lifecycle_current/${current.projectionId}`,
      data: {
        ...winner,
        projectionSchemaVersion: 1,
        projectionId: current.projectionId,
        currentEventId: winner.eventId,
      },
    },
    correctedEvent: original.data,
    supersededCorrection: inForce,
    previousCurrentState: current.snapshot.data ?? null,
  };
};

export const applyUvDetectorInstallationCorrection = (
  tx: WorkflowTransaction,
  plan: UvDetectorCorrectionWritePlan,
): void => {
  tx.create(plan.correction.path, plan.correction.data);
  tx.set(plan.currentState.path, plan.currentState.data);
};
