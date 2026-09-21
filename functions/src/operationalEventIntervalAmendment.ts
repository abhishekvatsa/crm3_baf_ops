import {createHash} from "crypto";
import {AssetHierarchyMutationError} from "./assetHierarchyMutation";
import {stableJson} from "./stableJson";

type JsonMap = {[key: string]: unknown};
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export const OPERATIONAL_INTERVAL_AMENDMENTS = "operational_event_interval_amendments";
export const OPERATIONAL_INTERVAL_AMENDMENT = "AMEND_OPERATIONAL_EVENT_INTERVAL";
export interface IntervalAmendmentRequest {
  occurrenceIndex: number;
  expectedEffectiveResolvedAt: string;
  correctedResolvedAt: string;
  supersedesAmendmentId: string | null;
}
function fail(reasonCode: string, message: string): never {
  throw new AssetHierarchyMutationError("failed-precondition", message, {reasonCode});
}
function record(value: unknown): JsonMap {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    fail("operational-interval-amendment-malformed", "The interval amendment evidence is malformed.");
  }
  return value as JsonMap;
}
function text(value: unknown, maximum: number): string {
  if (typeof value !== "string" || value.trim().length === 0 || value.length > maximum) {
    fail("operational-interval-amendment-malformed", "The interval amendment text is invalid.");
  }
  return value as string;
}
export function intervalAmendmentInstant(value: unknown): string {
  let date: Date;
  if (Object.prototype.toString.call(value) === "[object Date]") {
    try { date = new Date(Date.prototype.getTime.call(value)); }
    catch (_) { fail("operational-interval-amendment-malformed", "An interval time is invalid."); }
  }
  else if (typeof value === "string") date = new Date(value);
  else {
    const raw = record(value);
    const nanos = raw.nanoseconds ?? raw._nanoseconds;
    const seconds = raw.seconds ?? raw._seconds;
    if (!Number.isSafeInteger(seconds) || !Number.isSafeInteger(nanos) ||
        (nanos as number) < 0 || (nanos as number) >= 1000000000 || (nanos as number) % 1000000 !== 0) {
      fail("operational-interval-amendment-precision", "An exact retained interval time is required; unsupported precision is not rounded.");
    }
    date = new Date((seconds as number) * 1000 + (nanos as number) / 1000000);
  }
  if (!Number.isFinite(date.getTime())) fail("operational-interval-amendment-malformed", "An interval time is invalid.");
  const result = date.toISOString();
  if (typeof value === "string" && value !== result) {
    fail("operational-interval-amendment-precision", "An interval command must retain its exact UTC instant.");
  }
  return result;
}
function exactKeys(value: JsonMap, fields: string[]): void {
  if (Object.keys(value).sort().join(",") !== fields.sort().join(",")) {
    fail("operational-interval-amendment-malformed", "The interval amendment has unsupported or missing fields.");
  }
}
export function parseIntervalAmendment(value: unknown): IntervalAmendmentRequest {
  const raw = record(value);
  exactKeys(raw, ["occurrenceIndex", "expectedEffectiveResolvedAt", "correctedResolvedAt", "supersedesAmendmentId"]);
  if (!Number.isSafeInteger(raw.occurrenceIndex) || (raw.occurrenceIndex as number) < 0 ||
      (raw.occurrenceIndex as number) > 100 ||
      (raw.supersedesAmendmentId != null &&
        (typeof raw.supersedesAmendmentId !== "string" || !UUID.test(raw.supersedesAmendmentId)))) {
    fail("operational-interval-amendment-malformed", "The reviewed occurrence or predecessor identity is invalid.");
  }
  if (typeof raw.expectedEffectiveResolvedAt !== "string" || typeof raw.correctedResolvedAt !== "string") {
    fail("operational-interval-amendment-malformed", "The reviewed and corrected interval ends must be UTC text.");
  }
  return {occurrenceIndex: raw.occurrenceIndex as number,
    expectedEffectiveResolvedAt: intervalAmendmentInstant(raw.expectedEffectiveResolvedAt),
    correctedResolvedAt: intervalAmendmentInstant(raw.correctedResolvedAt),
    supersedesAmendmentId: raw.supersedesAmendmentId as string | null};
}
const INTERVAL_FIELDS = ["eventType", "title", "description", "severity", "startedAt", "resolvedAt", "scope",
  "affectedAssetClassIds", "affectedAssetInstanceIds", "issueLinkIds", "linkedIssueIds", "resolvedByUid", "resolvedByName", "resolutionNote"];
export function rawOperationalInterval(event: JsonMap, index: number): JsonMap {
  const completed = event.completedIntervals as JsonMap[];
  if (!Array.isArray(completed) || index > completed.length || index < 0 ||
      (index === completed.length && event.status !== "resolved")) {
    fail("operational-interval-not-closed", "Select a closed occurrence to amend; a recurrence is not a historical correction.");
  }
  return index < completed.length ? completed[index] : Object.fromEntries(
    INTERVAL_FIELDS.filter(field => Object.prototype.hasOwnProperty.call(event, field)).map(field => [field, event[field]]));
}
function nextStart(event: JsonMap, index: number): string | null {
  const completed = event.completedIntervals as JsonMap[];
  return index < completed.length ? intervalAmendmentInstant(
    index + 1 < completed.length ? completed[index + 1].startedAt : event.startedAt) : null;
}
export function intervalAmendmentHeads(event: JsonMap): JsonMap {
  if (!Object.prototype.hasOwnProperty.call(event, "intervalEndAmendments")) return {};
  const heads = record(event.intervalEndAmendments);
  if (Object.keys(heads).length > 101) fail("operational-interval-amendment-malformed", "Too many occurrence amendments.");
  for (const [key, value] of Object.entries(heads)) {
    if (!/^(0|[1-9][0-9]{0,2})$/.test(key) || Number(key) > 100) {
      fail("operational-interval-amendment-malformed", "The stored occurrence identity is invalid.");
    }
    const head = record(value);
    exactKeys(head, ["amendmentId", "originalResolvedAt", "correctedResolvedAt", "amendedAt", "amendedByUid", "amendedByName", "reason", "supersedesAmendmentId"]);
    const raw = rawOperationalInterval(event, Number(key));
    const start = intervalAmendmentInstant(raw.startedAt);
    const original = intervalAmendmentInstant(raw.resolvedAt);
    const corrected = intervalAmendmentInstant(head.correctedResolvedAt);
    const amendedAt = intervalAmendmentInstant(head.amendedAt);
    const following = nextStart(event, Number(key));
    if (!UUID.test(text(head.amendmentId, 64)) ||
        (head.supersedesAmendmentId != null && (!UUID.test(text(head.supersedesAmendmentId, 64)) || head.supersedesAmendmentId === head.amendmentId)) ||
        intervalAmendmentInstant(head.originalResolvedAt) !== original || corrected < start || corrected > amendedAt ||
        amendedAt > intervalAmendmentInstant(event.updatedAt) ||
        (following != null && corrected > following)) {
      fail("operational-interval-amendment-chronology", "The occurrence amendment has contradictory identity or chronology.");
    }
    text(head.amendedByUid, 128); text(head.amendedByName, 200); text(head.reason, 1000);
  }
  return heads;
}
export function canonicalIntervalEvidence(value: unknown): unknown {
  if (Object.prototype.toString.call(value) === "[object Date]") return intervalAmendmentInstant(value);
  if (Array.isArray(value)) return value.map(canonicalIntervalEvidence);
  if (value != null && typeof value === "object") {
    const raw = value as JsonMap;
    if (typeof raw.toDate === "function" ||
        ((raw.seconds ?? raw._seconds) != null && (raw.nanoseconds ?? raw._nanoseconds) != null)) {
      return intervalAmendmentInstant(value);
    }
    return Object.fromEntries(Object.entries(raw).map(([key, item]) => [key, canonicalIntervalEvidence(item)]));
  }
  return value;
}
export function intervalAmendmentDigest(value: JsonMap): string {
  const retained = {...value}; delete retained.evidenceDigest;
  return `operational-interval-amendment-v1-sha256:${createHash("sha256")
    .update(stableJson(canonicalIntervalEvidence(retained)), "utf8").digest("hex")}`;
}
export function sameRetainedOperationalInterval(serialized: unknown, interval: JsonMap): boolean {
  try {
    const original = record(JSON.parse(serialized as string));
    const normalized = (value: JsonMap): unknown => canonicalIntervalEvidence({
      ...value, issueLinkIds: value.issueLinkIds ?? [], linkedIssueIds: value.linkedIssueIds ?? [],
    });
    return stableJson(normalized(original)) === stableJson(normalized(interval));
  } catch (_) { return false; }
}
export function prepareOperationalIntervalAmendment(args: {
  current: JsonMap; requestId: string; eventId: string; expectedVersion: number;
  amendment: IntervalAmendmentRequest; reason: string; actorUid: string; actorName: string;
  now: Date; timestampFromDate: (value: Date) => unknown;
}): {record: JsonMap; heads: JsonMap} {
  const heads = intervalAmendmentHeads(args.current);
  const key = String(args.amendment.occurrenceIndex);
  const raw = rawOperationalInterval(args.current, args.amendment.occurrenceIndex);
  const previous = heads[key] == null ? null : record(heads[key]);
  const original = intervalAmendmentInstant(raw.resolvedAt);
  const effective = previous == null ? original : intervalAmendmentInstant(previous.correctedResolvedAt);
  const corrected = args.amendment.correctedResolvedAt;
  const now = args.now.toISOString();
  if (effective !== args.amendment.expectedEffectiveResolvedAt ||
      (previous?.amendmentId ?? null) !== args.amendment.supersedesAmendmentId) {
    fail("operational-interval-amendment-stale", "The occurrence end changed after review. Retain the draft and review the current amendment.");
  }
  if (corrected === effective) fail("operational-interval-amendment-no-change", "The proposed occurrence end is already effective.");
  const following = nextStart(args.current, args.amendment.occurrenceIndex);
  if (corrected < intervalAmendmentInstant(raw.startedAt) || corrected > now ||
      (following != null && corrected > following) || now < intervalAmendmentInstant(args.current.updatedAt)) {
    fail("operational-interval-amendment-chronology", "The corrected end must follow its start, precede the next recurrence and not invent a future or reversed recording time.");
  }
  const amendedAt = args.timestampFromDate(args.now);
  const result: JsonMap = {
    schemaVersion: 1, amendmentId: args.requestId, eventId: args.eventId,
    occurrenceIndex: args.amendment.occurrenceIndex, expectedEventVersion: args.expectedVersion,
    resultVersion: args.expectedVersion + 1,
    originalIntervalJson: stableJson(canonicalIntervalEvidence(raw)),
    priorEffectiveResolvedAt: args.timestampFromDate(new Date(effective)),
    correctedResolvedAt: args.timestampFromDate(new Date(corrected)),
    supersedesAmendmentId: args.amendment.supersedesAmendmentId,
    reason: args.reason, amendedAt, amendedByUid: args.actorUid, amendedByName: args.actorName,
  };
  result.evidenceDigest = intervalAmendmentDigest(result);
  return {record: result, heads: {...heads, [key]: {
    amendmentId: args.requestId, originalResolvedAt: raw.resolvedAt,
    correctedResolvedAt: result.correctedResolvedAt, amendedAt,
    amendedByUid: args.actorUid, amendedByName: args.actorName, reason: args.reason,
    supersedesAmendmentId: args.amendment.supersedesAmendmentId,
  }}};
}

/** Validate the current overlay against its immutable accepted head before any
 * ordinary writer carries it forward. Link projections may grow afterwards;
 * the physical interval and original closure evidence may not change. */
export async function verifyOperationalIntervalHeads(
  event: JsonMap,
  read: (amendmentId: string) => Promise<JsonMap | null>,
): Promise<void> {
  const heads = intervalAmendmentHeads(event);
  const withoutLinks = (value: JsonMap): JsonMap => {
    const result = {...value}; delete result.issueLinkIds; delete result.linkedIssueIds;
    return result;
  };
  for (const [key, value] of Object.entries(heads)) {
    const head = value as JsonMap;
    const retained = await read(head.amendmentId as string);
    let original: JsonMap | null = null;
    try { original = JSON.parse(retained?.originalIntervalJson as string) as JsonMap; } catch (_) { /* refused below */ }
    if (retained == null || original == null || Array.isArray(original) ||
        retained.schemaVersion !== 1 || retained.amendmentId !== head.amendmentId ||
        retained.eventId !== event.eventId || retained.occurrenceIndex !== Number(key) ||
        !Number.isSafeInteger(retained.expectedEventVersion) || (retained.expectedEventVersion as number) < 1 ||
        retained.resultVersion !== (retained.expectedEventVersion as number) + 1 ||
        (retained.resultVersion as number) > (event.version as number) ||
        retained.supersedesAmendmentId !== head.supersedesAmendmentId ||
        retained.reason !== head.reason || retained.amendedByUid !== head.amendedByUid ||
        retained.amendedByName !== head.amendedByName ||
        intervalAmendmentInstant(retained.amendedAt) !== intervalAmendmentInstant(head.amendedAt) ||
        intervalAmendmentInstant(retained.correctedResolvedAt) !== intervalAmendmentInstant(head.correctedResolvedAt) ||
        retained.evidenceDigest !== intervalAmendmentDigest(retained) ||
        stableJson(canonicalIntervalEvidence(withoutLinks(original))) !==
          stableJson(canonicalIntervalEvidence(withoutLinks(rawOperationalInterval(event, Number(key)))))) {
      fail("operational-interval-amendment-head-drift", "The effective occurrence end disagrees with its retained amendment. Preserve the evidence for review.");
    }
  }
}
