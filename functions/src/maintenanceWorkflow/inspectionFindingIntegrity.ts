import {WorkflowError} from "./errors";
import {DocSnapshot, WorkflowTransaction} from "./store";
import {JsonMap} from "./types";
import {persistedInstantText} from "./utils";

const terminal = new Set(["verifiedResolved", "acceptedCondition", "invalidated"]);
const statuses = new Set([...terminal, "open", "awaitingVerification", "correctiveActionLinked"]);
function historyRefusal(): never {
  throw new WorkflowError("failed-precondition",
    "Inspection observation history needs review before its current evidence can be certified.",
    {reasonCode: "inspection-observation-history-invalid"});
}
function id(value: unknown): string {
  if (typeof value !== "string" || !value || value.trim() !== value || value.includes("/")) historyRefusal();
  return value;
}
function instant(value: unknown): string {
  const result = persistedInstantText(value);
  if (result == null) historyRefusal();
  return result;
}

export interface InspectionHistory {
  readonly all: ReadonlyMap<string, JsonMap>;
  readonly effective: readonly JsonMap[];
  readonly current: JsonMap;
}

/** Recorded correction edges replace only the named reading. A correction's
 * later submission time never invalidates another physical observation. */
export function effectiveInspectionHistory(
  rows: readonly DocSnapshot[], campaignId: string, targetKey: string,
  pending?: JsonMap,
): InspectionHistory {
  const all = new Map<string, JsonMap>();
  for (const row of rows) {
    if (!row.exists || row.data == null || row.path !== `inspection_observations/${id(row.data.observationId)}`) historyRefusal();
    if (all.has(row.data.observationId as string)) historyRefusal();
    all.set(row.data.observationId as string, row.data);
  }
  if (pending != null) {
    const key = id(pending.observationId);
    if (all.has(key)) historyRefusal();
    all.set(key, pending);
  }
  const superseded = new Set<string>();
  for (const data of all.values()) {
    if (data.campaignId !== campaignId || data.targetKey !== targetKey ||
        typeof data.outOfRange !== "boolean") historyRefusal();
    instant(data.observedAt); instant(data.recordedAt);
    if (data.supersedesObservationId == null) continue;
    const replacedId = id(data.supersedesObservationId);
    const replaced = all.get(replacedId);
    if (replaced == null || superseded.has(replacedId) ||
        instant(data.recordedAt) < instant(replaced.recordedAt) ||
        ["definitionId", "definitionVersion", "assetClassId", "assetInstanceId", "subjectSerialNumber", "componentNodeId"]
          .some((key) => (data[key] ?? null) !== (replaced[key] ?? null))) historyRefusal();
    superseded.add(replacedId);
    const visited = new Set<string>([id(data.observationId)]);
    let parent: JsonMap | undefined = replaced;
    while (parent != null) {
      const parentId = id(parent.observationId);
      if (visited.has(parentId)) historyRefusal();
      visited.add(parentId);
      parent = parent.supersedesObservationId == null ? undefined : all.get(id(parent.supersedesObservationId));
      if (parent === undefined && all.get(parentId)?.supersedesObservationId != null) historyRefusal();
    }
  }
  const effective = [...all.values()].filter((data) => !superseded.has(id(data.observationId)))
    .sort((a, b) => instant(b.observedAt).localeCompare(instant(a.observedAt)) ||
      id(b.observationId).localeCompare(id(a.observationId)));
  if (effective.length === 0) historyRefusal();
  return {all, effective, current: effective[0]};
}

export async function readInspectionHistory(
  tx: WorkflowTransaction, campaignId: string, targetKey: string, pending?: JsonMap,
): Promise<InspectionHistory> {
  return effectiveInspectionHistory(await tx.query("inspection_observations", [
    {field: "campaignId", op: "==", value: campaignId},
    {field: "targetKey", op: "==", value: targetKey},
  ]), campaignId, targetKey, pending);
}

/** Keep the episode's original recording boundary stable while deriving first
 * adverse evidence and recurrence from its surviving readings. If correction
 * removes every adverse reading, technical resolution has no remaining basis:
 * preserve the episode for explicit accepted-condition/invalidation review. */
export function inspectionEpisodeProjection(history: InspectionHistory, previous: JsonMap | null): JsonMap {
  const originId = id(previous?.episodeOriginObservationId ?? previous?.firstObservationId ?? history.current.observationId);
  const origin = history.all.get(originId);
  if (origin == null) historyRefusal();
  const originRecordedAt = instant(origin.recordedAt);
  const belongs = (reading: JsonMap): boolean => {
    let root = reading;
    while (true) {
      if (root.observationId === originId) return true;
      if (root.supersedesObservationId == null) break;
      root = history.all.get(id(root.supersedesObservationId))!;
    }
    // campaignVersionAtObservation orders real commands even when their server
    // recording instants coincide. Legacy rows retain their recording boundary.
    if (typeof root.campaignVersionAtObservation === "number" && typeof origin.campaignVersionAtObservation === "number") {
      return root.campaignVersionAtObservation >= origin.campaignVersionAtObservation;
    }
    return instant(root.recordedAt) >= originRecordedAt;
  };
  const adverse = history.effective.filter((data) => belongs(data) && data.outOfRange === true);
  const first = adverse.at(-1);
  return {
    episodeOriginObservationId: originId,
    firstObservationId: first?.observationId ?? previous?.firstObservationId ?? originId,
    firstObservedAt: first == null ? previous?.firstObservedAt ?? origin.observedAt : instant(first.observedAt),
    // Schema-1 clients require a positive historical recurrence counter. Keep
    // it readable when correction removes the basis; the separate effective
    // count and review marker describe the surviving evidence truthfully.
    recurrenceCount: adverse.length || Math.max(1, Number(previous?.recurrenceCount ?? 1)),
    effectiveAdverseObservationCount: adverse.length,
    evidenceReviewRequired: first == null,
    evidenceReviewReason: first == null ? "inspection-episode-adverse-basis-corrected" : null,
  };
}

export function activeInspectionFindings(rows: readonly DocSnapshot[], targetKey: string): readonly DocSnapshot[] {
  if (rows.some((row) => row.data == null || row.data.targetKey !== targetKey ||
      row.path !== `inspection_findings/${id(row.data.findingId)}` || !statuses.has(String(row.data.status)))) {
    throw new WorkflowError("failed-precondition", "Inspection finding status needs review.",
      {reasonCode: "inspection-finding-population-conflict", targetKey});
  }
  return rows.filter((row) => !terminal.has(String(row.data!.status)));
}

function originalReadingVersion(history: InspectionHistory, observationId: unknown): number {
  let reading = history.all.get(id(observationId));
  if (reading == null) historyRefusal();
  while (reading.supersedesObservationId != null) reading = history.all.get(id(reading.supersedesObservationId))!;
  const version = reading.campaignVersionAtObservation;
  if (!Number.isSafeInteger(version) || (version as number) < 1) historyRefusal();
  return version as number;
}

/** A terminal decision covers only the episode's original recording boundary
 * through its saved reviewed reading. Later unowned readings do not silently
 * become part of that decision. Correction chains retain their original order.
 * Ambiguous historical ownership must be reviewed rather than guessed. */
export function terminalInspectionEvidenceOwner(
  rows: readonly DocSnapshot[], history: InspectionHistory, observationId: string,
): DocSnapshot | null {
  const version = originalReadingVersion(history, observationId);
  const owners = rows.filter((row) => {
    if (!terminal.has(String(row.data?.status))) return false;
    const first = originalReadingVersion(history, row.data!.episodeOriginObservationId ?? row.data!.firstObservationId);
    const reviewed = originalReadingVersion(history, row.data!.currentObservationId);
    if (reviewed < first) historyRefusal();
    return first <= version && version <= reviewed;
  });
  if (owners.length > 1) historyRefusal();
  return owners[0] ?? null;
}

export function assertInspectionEvidenceWithinEpisode(history: InspectionHistory, finding: JsonMap): void {
  if (originalReadingVersion(history, history.current.observationId) <
      originalReadingVersion(history, finding.episodeOriginObservationId ?? finding.firstObservationId)) {
    throw new WorkflowError("failed-precondition",
      "This correction exposes earlier episode evidence. Review the separate finding histories before changing this decision.",
      {reasonCode: "inspection-correction-earlier-episode-review", findingId: finding.findingId,
        effectiveObservationId: history.current.observationId});
  }
}

/** Older terminal episodes remain separate history. Reopening one after a
 * later episode exists would otherwise absorb that episode's adjudicated
 * observations through a lower-bound-only recurrence projection. */
export function assertInspectionFindingEpisodeCurrent(
  rows: readonly DocSnapshot[], findingId: string, history: InspectionHistory,
): void {
  const current = rows.find((row) => row.data?.findingId === findingId);
  if (current?.data == null) return;
  const ordinal = (finding: JsonMap): number => {
    const origin = history.all.get(id(finding.episodeOriginObservationId ?? finding.firstObservationId));
    const version = origin?.campaignVersionAtObservation;
    if (!Number.isSafeInteger(version) || (version as number) < 1) historyRefusal();
    return version as number;
  };
  const originalVersion = ordinal(current.data);
  const newer = rows.filter((row) => row.data!.findingId !== findingId && ordinal(row.data!) > originalVersion);
  if (newer.length > 0) {
    throw new WorkflowError("failed-precondition",
      "A later finding episode exists for this target. Review or reopen that episode; this older history remains separate.",
      {reasonCode: "inspection-finding-newer-episode-exists", findingId,
        newerFindingIds: newer.map((row) => id(row.data!.findingId))});
  }
}

export function assertInspectionFindingActivation(rows: readonly DocSnapshot[], findingId: string, targetKey: string,
  campaign: JsonMap, history: InspectionHistory): void {
  if (campaign.status !== "open") {
    throw new WorkflowError("failed-precondition", "Reopen the inspection campaign before activating a finding.",
      {reasonCode: "inspection-finding-campaign-not-open", targetKey});
  }
  const competing = activeInspectionFindings(rows, targetKey).filter((row) => row.data!.findingId !== findingId);
  if (competing.length > 0) {
    throw new WorkflowError("failed-precondition",
      "Another active finding exists for this target. Review that episode before reopening or activating this one.",
      {reasonCode: "inspection-finding-population-conflict", targetKey,
        competingFindingIds: competing.map((row) => id(row.data!.findingId))});
  }
  assertInspectionFindingEpisodeCurrent(rows, findingId, history);
}

/** All finding writers read the same campaign and touch this revision. Thus
 * empty-query activation and recurrence/reopen races share a real document
 * conflict, without changing the existing client campaign-version contract. */
export function touchInspectionFindingPopulation(tx: WorkflowTransaction, campaignId: string, campaign: JsonMap): void {
  const revision = campaign.findingPopulationRevision ?? 0;
  if (!Number.isSafeInteger(revision) || (revision as number) < 0 || (revision as number) >= Number.MAX_SAFE_INTEGER) historyRefusal();
  tx.update(`inspection_campaigns/${campaignId}`, {findingPopulationRevision: (revision as number) + 1});
}
