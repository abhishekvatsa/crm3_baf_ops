import {createHash} from "crypto";
import {AssetHierarchyMutationError} from "./assetHierarchyMutation";
import {persistedInstantMillis} from "./persistedInstant";
import {stableJson} from "./stableJson";

type JsonMap = {[key: string]: unknown};

export const BURNER_EVIDENCE_FIELDS = [
  ...Array.from({length: 8}, (_, index) => [
    ...["flameObservation", "redHotObserved", "microampReading", "remarks"]
      .map((field) => `burners.${index + 1}.${field}`),
    ...["condition", "remarks"].map((field) => `uv.${index + 1}.${field}`),
  ]).flat(),
  "draftSealRedHotObserved", "hotAirAtDraftSealObserved",
];

export function evidenceInstant(value: unknown): string | null {
  let milliseconds = persistedInstantMillis(value);
  if (!Number.isFinite(milliseconds) && value != null &&
      Object.prototype.toString.call(value) === "[object Date]") {
    milliseconds = Date.prototype.getTime.call(value);
  }
  return Number.isFinite(milliseconds) ? new Date(milliseconds).toISOString() : null;
}

export function roundEvidenceHash(data: JsonMap): string {
  const provenance = data.evidenceProvenance;
  return createHash("sha256").update(stableJson({
    ...data, observedAt: evidenceInstant(data.observedAt),
    ...(provenance != null && typeof provenance === "object" && !Array.isArray(provenance) ? {
      evidenceProvenance: Object.fromEntries(Object.entries(provenance as JsonMap)
        .map(([field, value]) => {
          if (value == null || typeof value !== "object" || Array.isArray(value)) {
            return [field, value];
          }
          const entry = value as JsonMap;
          return [field, {...entry,
            observedAt: evidenceInstant(entry.observedAt) ?? entry.observedAt}];
        })),
    } : {}),
  }), "utf8").digest("hex");
}

const unknownEvidence = (): JsonMap => ({
  kind: "unknown", sourceRoundId: null, observedAt: null,
  observerUid: null, observerName: null,
});

function inheritedEvidence(before: JsonMap | null, field: string): JsonMap {
  if (before == null) return unknownEvidence();
  if (before.evidenceProvenance != null) {
    const entry = (before.evidenceProvenance as JsonMap)[field] as JsonMap | undefined;
    if (entry == null || !["observed", "inherited", "directiveDisposition", "unknown"]
      .includes(entry.kind as string) ||
      (entry.kind !== "unknown" &&
        (typeof entry.sourceRoundId !== "string" || entry.sourceRoundId.length === 0 ||
          evidenceInstant(entry.observedAt) == null ||
          typeof entry.observerUid !== "string" || entry.observerUid.length === 0 ||
          typeof entry.observerName !== "string" || entry.observerName.length === 0))) {
      throw new AssetHierarchyMutationError("data-loss",
        "The condition evidence provenance needs reconciliation.",
        {reasonCode: "burner-condition-provenance-malformed", field});
    }
    return entry.kind === "unknown" ? unknownEvidence() : {
      ...entry, kind: "inherited", observedAt: evidenceInstant(entry.observedAt),
    };
  }
  // Old compliance rounds contain mixed-age values without immutable ancestry.
  // The directive's original round is not necessarily their copied baseline.
  if (typeof before.roundNote === "string" &&
      before.roundNote.startsWith("I&A compliance for directive ")) {
    return unknownEvidence();
  }
  if ((field.startsWith("uv.") || !field.includes(".")) && before.schemaVersion !== 2) {
    return unknownEvidence();
  }
  const observedAt = evidenceInstant(before.observedAt);
  if (observedAt == null || typeof before.roundId !== "string" ||
      typeof before.recordedByUid !== "string" || typeof before.recordedByName !== "string") {
    return unknownEvidence();
  }
  return {kind: "inherited", sourceRoundId: before.roundId, observedAt,
    observerUid: before.recordedByUid, observerName: before.recordedByName};
}

export function conditionProvenance(args: {
  before: JsonMap | null; roundId: string; observedAt: string;
  actorUid: string; actorName: string; assertedFields: ReadonlySet<string>;
  kind: "observed" | "directiveDisposition";
}): JsonMap {
  return Object.fromEntries(BURNER_EVIDENCE_FIELDS.map((field) => [field,
    args.assertedFields.has(field) ? {
      kind: args.kind, sourceRoundId: args.roundId, observedAt: args.observedAt,
      observerUid: args.actorUid, observerName: args.actorName,
    } : inheritedEvidence(args.before, field),
  ]));
}

export function partialConditionValues<T extends JsonMap>(
  request: T, before: JsonMap | null, observedFields: readonly string[],
): T {
  const observed = new Set(observedFields);
  const choose = (field: string, supplied: unknown, retained: unknown, empty: unknown) =>
    observed.has(field) ? supplied : retained === undefined ? empty : retained;
  const beforeBurners = (before?.observations ?? []) as JsonMap[];
  const beforeUv = (before?.uvObservations ?? []) as JsonMap[];
  return {
    ...request,
    observations: (request.observations as JsonMap[]).map((item, index) => ({
      ...item,
      ...Object.fromEntries(["flameObservation", "redHotObserved", "microampReading", "remarks"]
        .map((field) => [field, choose(`burners.${index + 1}.${field}`, item[field],
          beforeBurners[index]?.[field], field === "flameObservation" ? "notChecked" :
            field === "redHotObserved" ? false : field === "remarks" ?
              "Not assessed in this partial condition update." : null)])),
    })),
    uvObservations: (request.uvObservations as JsonMap[]).map((item, index) => ({
      ...item,
      condition: choose(`uv.${index + 1}.condition`, item.condition,
        beforeUv[index]?.condition, "serviceable"),
      remarks: choose(`uv.${index + 1}.remarks`, item.remarks, beforeUv[index]?.remarks, null),
    })),
    ...Object.fromEntries(["draftSealRedHotObserved", "hotAirAtDraftSealObserved"]
      .map((field) => [field, choose(field, request[field], before?.[field], false)])),
  };
}
