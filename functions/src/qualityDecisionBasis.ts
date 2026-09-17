import {stableJson} from "./stableJson";

/**
 * What a quality decision was actually made about.
 *
 * A closed decision covers particular evidence: a classification, a severity,
 * an observation, and the physical subjects the case names. Three kinds of
 * difference must not be confused:
 *
 *  - a change of representation (the same subjects in another order, an
 *    optional value absent rather than explicitly null, a renamed asset or a
 *    bumped revision) carries no business meaning and stays editorial;
 *  - a change of evidence (severity, classification, observation, or which
 *    physical subject is implicated, down to the governed component and the
 *    Inner Cover recorded on it) needs the decision made again;
 *  - a repair of earlier drift, which must not hand an old decision a case it
 *    never covered.
 *
 * This module holds the one comparison all three use, so the write-side guard,
 * the projection repair and any later reviewed repair agree on what "the same
 * case" means. It compares meaning only: stored order, frozen command bytes
 * and audit evidence are never rewritten to satisfy it.
 */

type JsonMap = Record<string, unknown>;

/** Fields that identify which physical thing a governed reference names. */
const REFERENCE_IDENTITY_FIELDS = [
  "scope",
  "assetClassId",
  "assetInstanceId",
  "assetNumber",
  "nodeId",
  "componentInstanceId",
  "componentTag",
];

/** Fields that identify which Inner Cover is recorded on that subject. */
const INNER_COVER_IDENTITY_FIELDS = [
  "positionState",
  "baseAssetInstanceId",
  "baseAssetNumber",
  "innerCoverId",
  "linkageId",
];

/** Evidence a closed decision rests on, beyond its physical subjects. */
const DECISION_EVIDENCE_FIELDS = [
  "abnormalityTypeId",
  "severity",
  "component",
  "observedReason",
];

const isMap = (value: unknown): value is JsonMap =>
  value != null && typeof value === "object" && !Array.isArray(value);

const list = (value: unknown): ReadonlyArray<unknown> =>
  Array.isArray(value) ? value : [];

/** An absent optional key and an explicit null describe one value. */
const optional = (value: unknown): unknown => value ?? null;

function pick(
  value: unknown,
  fields: ReadonlyArray<string>,
): JsonMap | null {
  if (!isMap(value)) return null;
  const basis: JsonMap = {};
  for (const field of fields) basis[field] = optional(value[field]);
  return basis;
}

export function assetIdentity(value: unknown): string {
  const asset = isMap(value) ? value : {};
  return `${String(asset.assetType)}:${String(asset.assetNumber)}`;
}

/**
 * The stable identity of one governed reference: which asset, which component
 * node or instance, and which Inner Cover was recorded on it. Names, hierarchy
 * paths, ownership labels and revision counters are deliberately excluded, so
 * renaming an asset or re-publishing its class never reopens a decision.
 */
export function governedSubjectIdentity(value: unknown): JsonMap | null {
  const reference = isMap(value) ?
    (isMap(value.assetHierarchyRef) ? value.assetHierarchyRef : value) : null;
  const basis = pick(reference, REFERENCE_IDENTITY_FIELDS);
  if (basis == null) return null;
  basis.innerCoverAssociation = pick(
    (reference as JsonMap).innerCoverAssociation,
    INNER_COVER_IDENTITY_FIELDS,
  );
  return basis;
}

/**
 * Every physical subject the record names, as canonical text, in a stable
 * order. Order carries no business meaning, so it is normalised here and only
 * here; the stored arrays keep the order they were written in.
 */
export function decisionSubjects(record: JsonMap): ReadonlyArray<string> {
  const governed = new Map<string, JsonMap | null>();
  for (const reference of list(record.affectedAssetHierarchyRefs)) {
    governed.set(assetIdentity(reference), governedSubjectIdentity(reference));
  }
  return list(record.affectedAssets).map((asset) => {
    const identity = assetIdentity(asset);
    const reference = governed.get(identity) ??
      (isMap(asset) && asset.assetHierarchyRef != null ?
        governedSubjectIdentity(asset) : null);
    return `${identity}|${stableJson(reference)}`;
  }).slice().sort();
}

/**
 * The name of the first field whose meaning differs between two revisions of a
 * case, or null when they describe the same case. `affectedAssets` names a
 * different set of subjects; `affectedAssetHierarchyRefs` names the same
 * subjects recorded against different governed physical context.
 */
export function decisionBasisChange(
  before: JsonMap,
  after: JsonMap,
): string | null {
  const changed = DECISION_EVIDENCE_FIELDS.find((field) =>
    stableJson(optional(before[field])) !== stableJson(optional(after[field])));
  if (changed != null) return changed;
  const beforeSubjects = decisionSubjects(before);
  const afterSubjects = decisionSubjects(after);
  if (stableJson(beforeSubjects) === stableJson(afterSubjects)) return null;
  const identities = (subjects: ReadonlyArray<string>): string =>
    stableJson(subjects.map((subject) => subject.split("|")[0]));
  return identities(beforeSubjects) === identities(afterSubjects) ?
    "affectedAssetHierarchyRefs" : "affectedAssets";
}

/**
 * Whether a warning's own copy of the evidence differs in meaning from the
 * abnormality it projects. A classification renamed in the master is not a
 * difference in meaning; the severity, the observation, the component or the
 * subjects are.
 */
export function warningDecisionBasisStale(
  warning: JsonMap,
  abnormality: JsonMap,
): boolean {
  // A warning records its subjects by identity alone, so both sides are
  // compared by identity here.
  const subjects = (value: unknown): ReadonlyArray<JsonMap> =>
    list(value).map((asset) => ({
      assetType: isMap(asset) ? asset.assetType : null,
      assetNumber: isMap(asset) ? asset.assetNumber : null,
    }));
  return decisionBasisChange(
    {
      abnormalityTypeId: abnormality.abnormalityTypeId,
      severity: warning.sourceSeverity,
      component: warning.component,
      observedReason: warning.warningReason,
      affectedAssets: subjects(warning.affectedAssets),
    },
    {
      abnormalityTypeId: abnormality.abnormalityTypeId,
      severity: abnormality.severity,
      component: abnormality.component,
      observedReason: abnormality.observedReason,
      affectedAssets: subjects(abnormality.affectedAssets),
    },
  ) != null;
}
