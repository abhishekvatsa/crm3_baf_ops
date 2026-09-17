import {createHash} from "crypto";
import {isFiveDigitChargeNumber} from "./chargeNumber";
import {
  canonicalQualityWarningGaps,
  validateQualityCasePostcondition,
  validateQualityWarningRecord,
} from "./qualityMutation";
import {
  decisionBasisChange,
  decisionSubjects,
  warningDecisionBasisStale,
  warningSeverityForCase,
} from "./qualityDecisionBasis";
import {isValidAffectedAssetHierarchyReference} from
  "./affectedAssetHierarchyReference";
import {
  isValidPersistedInstant,
  persistedInstantMillis,
} from "./persistedInstant";
import {stableJson} from "./stableJson";

import {
  canonicalApprovedUserAuthority,
  UserAuthorityJsonMap,
} from "./userAuthority";

export type ChargeAbnormalityMutationHttpsErrorCode =
  | "invalid-argument"
  | "unauthenticated"
  | "permission-denied"
  | "not-found"
  | "failed-precondition"
  | "unavailable"
  | "aborted"
  | "data-loss"
  | "internal";

export type ChargeAbnormalityMutationOperation =
  | "CREATE"
  | "UPDATE"
  | "SOFT_DELETE"
  | "RECONCILE_QUALITY_CASE";

export type ChargeAbnormalityMutationFirestoreLike = {
  collection: (name: string) => ChargeAbnormalityMutationCollectionLike;
  runTransaction: <T>(
    fn: (transaction: ChargeAbnormalityMutationTransactionLike) => Promise<T>,
  ) => Promise<T>;
};

type ChargeAbnormalityMutationCollectionLike = {
  doc: (id: string) => ChargeAbnormalityMutationDocumentRefLike;
};

type ChargeAbnormalityMutationDocumentRefLike = {
  id?: string;
  path?: string;
  get: () => Promise<ChargeAbnormalityMutationDocumentSnapshotLike>;
};

type ChargeAbnormalityMutationDocumentSnapshotLike = {
  exists: boolean;
  id?: string;
  data: () => UserAuthorityJsonMap | undefined;
};

type ChargeAbnormalityMutationTransactionLike = {
  get: (
    ref: ChargeAbnormalityMutationDocumentRefLike,
  ) => Promise<ChargeAbnormalityMutationDocumentSnapshotLike>;
  set: (
    ref: ChargeAbnormalityMutationDocumentRefLike,
    data: UserAuthorityJsonMap,
    options?: UserAuthorityJsonMap,
  ) => void;
};

type AffectedAsset = {
  readonly assetType: string;
  readonly assetNumber: number;
  readonly assetHierarchyRef?: UserAuthorityJsonMap;
};

type AffectedAssetHierarchyReference = {
  readonly assetType: string;
  readonly assetNumber: number;
  readonly assetHierarchyRef: UserAuthorityJsonMap;
};

type ParsedChargeAbnormalityUpdate = {
  readonly abnormalityTypeId: string;
  readonly severity: string;
  readonly affectedAssets: ReadonlyArray<AffectedAsset>;
  readonly affectedAssetHierarchyRefs:
    ReadonlyArray<AffectedAssetHierarchyReference> | null;
  readonly component: string | null;
  readonly observedReason: string;
  readonly description: string | null;
  readonly possibleRootReasonCategory: string;
  readonly possibleRootReasonNotes: string | null;
  readonly reannealingStatus: string;
  readonly reannealedToChargeNo: number | null;
};

type ParsedChargeAbnormalityMutationRequest = {
  readonly requestId: string;
  readonly abnormalityId: string;
  readonly operation: ChargeAbnormalityMutationOperation;
  readonly expectedVersion: number;
  readonly reason: string;
  readonly update: ParsedChargeAbnormalityUpdate | null;
  readonly creation?: UserAuthorityJsonMap;
  readonly expectedWarningVersion?: number;
  readonly payloadFingerprint: string;
};

export interface ChargeAbnormalityMutationResult {
  readonly ok: true;
  readonly requestId: string;
  readonly abnormalityId: string;
  readonly operation: ChargeAbnormalityMutationOperation;
  readonly version: number;
  readonly auditId: string;
  readonly committedAt: string;
  readonly idempotentReplay: boolean;
  readonly abnormality: UserAuthorityJsonMap;
}

const REQUEST_ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const OPERATIONS = new Set<ChargeAbnormalityMutationOperation>([
  "CREATE",
  "UPDATE",
  "SOFT_DELETE",
  "RECONCILE_QUALITY_CASE",
]);
const CATEGORIES = new Set([
  "process",
  "equipment",
  "resultQuality",
  "reannealing",
  "other",
]);
const SEVERITIES = new Set(["low", "medium", "high", "critical"]);
const ROOT_REASON_CATEGORIES = new Set([
  "unknown",
  "baseRelated",
  "furnaceRelated",
  "forceCoolerRelated",
  "atmosphereRelated",
  "thermocoupleTemperature",
  "cycleInterruption",
  "materialOrCoilCondition",
  "operationsRelated",
  "other",
]);
const REANNEALING_STATUSES = new Set([
  "notApplicable",
  "pendingDecision",
  "required",
  "notRequired",
  "completed",
]);
const ASSET_TYPES = new Set([
  "base",
  "furnace",
  "forceCooler",
  "innerCover",
  "governedCustom",
]);
const COMMON_REQUEST_FIELDS = new Set([
  "requestId",
  "abnormalityId",
  "operation",
  "expectedVersion",
  "reason",
]);
const RECONCILE_REQUEST_FIELDS = new Set([
  ...COMMON_REQUEST_FIELDS,
  "expectedWarningVersion",
]);
const UPDATE_REQUEST_FIELDS = new Set([
  ...COMMON_REQUEST_FIELDS,
  "abnormalityTypeId",
  "severity",
  "affectedAssets",
  "affectedAssetHierarchyRefs",
  "component",
  "observedReason",
  "description",
  "possibleRootReasonCategory",
  "possibleRootReasonNotes",
  "reannealingStatus",
  "reannealedToChargeNo",
]);
const ABNORMALITY_FIELDS = new Set([
  "firestoreId",
  "sourceChargeNo",
  "abnormalityTypeId",
  "abnormalityTypeTitle",
  "abnormalityTypeCode",
  "category",
  "severity",
  "affectedAssets",
  "affectedAssetHierarchyRefs",
  "component",
  "observedReason",
  "description",
  "possibleRootReasonCategory",
  "possibleRootReasonNotes",
  "reannealingStatus",
  "reannealedToChargeNo",
  "loggedAt",
  "updatedAt",
  "loggedByUid",
  "loggedByName",
  "updatedByUid",
  "updatedByName",
  "linkedTicketFirestoreId",
  "linkedExecutionFirestoreId",
  "version",
  "isDeleted",
  "deletedAt",
  "deletedByUid",
  "deletedByName",
  "deleteReason",
  "_globalPullServerUpdatedAt",
]);
const REQUIRED_ABNORMALITY_FIELDS = [...ABNORMALITY_FIELDS].filter(
  (field) => field !== "_globalPullServerUpdatedAt" &&
    field !== "affectedAssetHierarchyRefs",
);
// Governed records now carry every optional key with an explicit null. Records
// written before that omitted them, where absence means "no value". It never
// stands in for a missing actor, charge, time or re-annealing result, so those
// fields stay required.
const LEGACY_NULLABLE_ABNORMALITY_FIELDS = new Set([
  "component",
  "description",
  "possibleRootReasonNotes",
  "loggedByName",
  "updatedByName",
  "linkedTicketFirestoreId",
  "linkedExecutionFirestoreId",
  "reannealedToChargeNo",
  "deletedAt",
  "deletedByUid",
  "deletedByName",
  "deleteReason",
]);

// The canonical null keys a record is missing, so a governed write stores the
// current representation without inventing evidence or rewriting history.
function canonicalNullableGaps(
  record: UserAuthorityJsonMap,
): UserAuthorityJsonMap {
  const gaps: UserAuthorityJsonMap = {};
  for (const field of LEGACY_NULLABLE_ABNORMALITY_FIELDS) {
    if (!Object.prototype.hasOwnProperty.call(record, field)) {
      gaps[field] = null;
    }
  }
  return gaps;
}

const MAX_AFFECTED_ASSETS = 50;

/**
 * Runs the shared quality-case postcondition before a standalone case is
 * committed, and reports a refusal in this handler's own vocabulary while
 * keeping the underlying reason and field for diagnosis.
 */
function assertCreatedCaseIsAdjudicable(plan: {
  readonly warningId: string;
  readonly warning: UserAuthorityJsonMap;
  readonly abnormalityId: string;
  readonly abnormality: UserAuthorityJsonMap;
}, message = "This abnormality would create a quality case that cannot be " +
  "decided. Nothing was saved."): void {
  try {
    validateQualityCasePostcondition(plan);
  } catch (error) {
    const cause = (error as {details?: unknown}).details;
    const causeDetails = cause != null && typeof cause === "object" ?
      cause as {reasonCode?: unknown; field?: unknown} : {};
    throw new ChargeAbnormalityMutationError("failed-precondition",
      message,
      {
        reasonCode: "charge-quality-case-postcondition-failed",
        ...(typeof causeDetails.reasonCode === "string" ?
          {causeReasonCode: causeDetails.reasonCode} : {}),
        ...(typeof causeDetails.field === "string" ?
          {field: causeDetails.field} : {}),
      });
  }
}

export class ChargeAbnormalityMutationError extends Error {
  readonly code: ChargeAbnormalityMutationHttpsErrorCode;
  readonly details?: unknown;

  constructor(
    code: ChargeAbnormalityMutationHttpsErrorCode,
    message: string,
    details?: unknown,
  ) {
    super(message);
    this.name = "ChargeAbnormalityMutationError";
    this.code = code;
    this.details = details;
  }
}

function invalidField(
  field: string,
  message: string,
  reasonCode = "invalid-field",
): never {
  throw new ChargeAbnormalityMutationError(
    "invalid-argument",
    message,
    {reasonCode, field},
  );
}

function cleanRequiredString(
  value: unknown,
  field: string,
  maxLength: number,
): string {
  if (typeof value !== "string") {
    return invalidField(field, `${field} must be a string.`);
  }
  const cleaned = value.trim();
  if (cleaned.length === 0 || cleaned.length > maxLength) {
    return invalidField(
      field,
      `${field} must contain between 1 and ${maxLength} characters.`,
    );
  }
  return cleaned;
}

function cleanOptionalString(
  value: unknown,
  field: string,
  maxLength: number,
): string | null {
  if (value == null) return null;
  if (typeof value !== "string") {
    return invalidField(field, `${field} must be a string or null.`);
  }
  const cleaned = value.trim();
  if (cleaned.length === 0) return null;
  if (cleaned.length > maxLength) {
    return invalidField(
      field,
      `${field} must not exceed ${maxLength} characters.`,
    );
  }
  return cleaned;
}

function cleanDocumentId(value: unknown, field: string): string {
  const id = cleanRequiredString(value, field, 512);
  if (id === "." || id === ".." || id.includes("/")) {
    return invalidField(
      field,
      `${field} is not a valid Firestore document identity.`,
      "invalid-document-id",
    );
  }
  return id;
}

function positiveSafeInteger(value: unknown, field: string): number {
  if (!Number.isSafeInteger(value) || (value as number) <= 0) {
    return invalidField(
      field,
      `${field} must be a positive safe integer.`,
      "invalid-integer",
    );
  }
  return value as number;
}

function optionalPositiveSafeInteger(
  value: unknown,
  field: string,
): number | null {
  return value == null ? null : positiveSafeInteger(value, field);
}

function enumValue(
  value: unknown,
  field: string,
  allowed: ReadonlySet<string>,
): string {
  const parsed = cleanRequiredString(value, field, 80);
  if (!allowed.has(parsed)) {
    return invalidField(
      field,
      `${field} is not a supported value.`,
      "unsupported-enum-value",
    );
  }
  return parsed;
}

function parseAffectedAssets(
  value: unknown,
  options: {readonly allowEmpty?: boolean} = {},
): ReadonlyArray<AffectedAsset> {
  if (!Array.isArray(value) ||
      (!options.allowEmpty && value.length === 0) ||
      value.length > MAX_AFFECTED_ASSETS) {
    return invalidField(
      "affectedAssets",
      options.allowEmpty ?
        `affectedAssets must contain at most ${MAX_AFFECTED_ASSETS} items.` :
        `affectedAssets must contain between 1 and ${MAX_AFFECTED_ASSETS} items.`,
    );
  }
  const seen = new Set<string>();
  return value.map((raw, index) => {
    if (
      raw == null ||
      typeof raw !== "object" ||
      Array.isArray(raw)
    ) {
      return invalidField(
        `affectedAssets[${index}]`,
        "Each affected asset must be a map.",
      );
    }
    const asset = raw as UserAuthorityJsonMap;
    const keys = Object.keys(asset);
    const hasHierarchyReference = Object.prototype.hasOwnProperty.call(
      asset,
      "assetHierarchyRef",
    );
    if (
      (keys.length !== 2 && !(keys.length === 3 && hasHierarchyReference)) ||
      !keys.includes("assetType") ||
      !keys.includes("assetNumber")
    ) {
      return invalidField(
        `affectedAssets[${index}]`,
        "Each affected asset must contain assetType, assetNumber, and an optional governed hierarchy reference.",
      );
    }
    const assetType = enumValue(
      asset.assetType,
      `affectedAssets[${index}].assetType`,
      ASSET_TYPES,
    );
    const assetNumber = positiveSafeInteger(
      asset.assetNumber,
      `affectedAssets[${index}].assetNumber`,
    );
    if (hasHierarchyReference &&
        !isValidAffectedAssetHierarchyReference(
          asset.assetHierarchyRef,
          assetNumber,
        )) {
      return invalidField(
        `affectedAssets[${index}].assetHierarchyRef`,
        "The governed hierarchy reference is malformed or identifies a different physical asset.",
        "invalid-asset-hierarchy-reference",
      );
    }
    const identity = `${assetType}:${assetNumber}`;
    if (seen.has(identity)) {
      return invalidField(
        "affectedAssets",
        "affectedAssets must not contain duplicates.",
        "duplicate-affected-asset",
      );
    }
    seen.add(identity);
    return {
      assetType,
      assetNumber,
      ...(hasHierarchyReference ? {
        assetHierarchyRef: asset.assetHierarchyRef as UserAuthorityJsonMap,
      } : {}),
    };
  });
}

function assetIdentity(asset: AffectedAsset): string {
  return `${asset.assetType}:${asset.assetNumber}`;
}

/**
 * Governed evidence recorded twice for one subject carries nothing the first
 * entry does not, so a reviewed repair collapses exact repeats. Two entries
 * that name the same subject with different content are a contradiction: only
 * a person can say which is true, so the repair refuses them.
 */
function collapseRepeatedHierarchyReferences(
  record: UserAuthorityJsonMap,
): {readonly record: UserAuthorityJsonMap; readonly repaired: boolean} {
  const value = record.affectedAssetHierarchyRefs;
  if (!Array.isArray(value)) return {record, repaired: false};
  const kept = new Map<string, unknown>();
  for (const entry of value) {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      return {record, repaired: false};
    }
    const identity = assetIdentity(entry as AffectedAsset);
    const first = kept.get(identity);
    if (first == null) {
      kept.set(identity, entry);
      continue;
    }
    if (stableJson(first) !== stableJson(entry)) {
      throw new ChargeAbnormalityMutationError(
        "failed-precondition",
        "This case records two different governed references for one " +
        "affected asset. A reviewer has to decide which one is correct.",
        {
          reasonCode: "charge-quality-case-conflicting-reference",
          field: "affectedAssetHierarchyRefs",
        },
      );
    }
  }
  if (kept.size === value.length) return {record, repaired: false};
  return {
    record: {...record, affectedAssetHierarchyRefs: [...kept.values()]},
    repaired: true,
  };
}

function parseAffectedAssetHierarchyRefs(
  value: unknown,
  affectedAssets: ReadonlyArray<AffectedAsset>,
): ReadonlyArray<AffectedAssetHierarchyReference> | null {
  const inline = affectedAssets
    .filter((asset) => asset.assetHierarchyRef != null)
    .map((asset) => ({
      assetType: asset.assetType,
      assetNumber: asset.assetNumber,
      assetHierarchyRef: asset.assetHierarchyRef as UserAuthorityJsonMap,
    }));
  if (value === undefined) return inline.length === 0 ? null : inline;
  if (!Array.isArray(value) || value.length > MAX_AFFECTED_ASSETS) {
    return invalidField(
      "affectedAssetHierarchyRefs",
      `affectedAssetHierarchyRefs must be a list of at most ${MAX_AFFECTED_ASSETS} items.`,
    );
  }
  if (inline.length > 0) {
    return invalidField(
      "affectedAssetHierarchyRefs",
      "Governed hierarchy evidence must use either the compatibility field or inline references, not both.",
      "duplicate-asset-hierarchy-representation",
    );
  }
  const affectedIdentities = new Set(affectedAssets.map(assetIdentity));
  const seen = new Set<string>();
  return value.map((raw, index) => {
    if (raw == null || typeof raw !== "object" || Array.isArray(raw)) {
      return invalidField(
        `affectedAssetHierarchyRefs[${index}]`,
        "Each governed hierarchy entry must be a map.",
      );
    }
    const parsed = parseAffectedAssets([raw])[0];
    const identity = assetIdentity(parsed);
    if (parsed.assetHierarchyRef == null || !affectedIdentities.has(identity)) {
      return invalidField(
        `affectedAssetHierarchyRefs[${index}]`,
        "Each governed hierarchy entry must identify one affected asset.",
        "orphan-asset-hierarchy-reference",
      );
    }
    // Set.prototype.add returns the set itself, so test membership first.
    if (seen.has(identity)) {
      return invalidField(
        "affectedAssetHierarchyRefs",
        "Governed hierarchy entries must not contain duplicates.",
        "duplicate-asset-hierarchy-reference",
      );
    }
    seen.add(identity);
    return {
      assetType: parsed.assetType,
      assetNumber: parsed.assetNumber,
      assetHierarchyRef: parsed.assetHierarchyRef,
    };
  });
}

function identityOnlyAffectedAssets(
  value: ReadonlyArray<AffectedAsset>,
): ReadonlyArray<AffectedAsset> {
  return value.map((asset) => ({
    assetType: asset.assetType,
    assetNumber: asset.assetNumber,
  }));
}

// A closed quality decision was made about particular evidence. Changing that
// evidence needs a reopened decision; editorial notes, a renamed asset and the
// same subjects in another order do not. The comparison itself lives in
// qualityDecisionBasis, so the repair below agrees with it.
function materialCaseChange(
  before: UserAuthorityJsonMap,
  after: UserAuthorityJsonMap,
): string | null {
  return decisionBasisChange(before, after);
}

/**
 * What a warning should say about its case, given the case as it now stands.
 *
 * A case that began as a maintenance issue is often only understood later, when
 * the coils come out wrong and someone documents what actually happened. That
 * documentation belongs to the same case, so the evidence a decision reads is
 * refreshed from it. Two fields are not refreshed for such a case: the summary
 * is the issue as it was reported, and the source version belongs to the issue
 * that raised it. Both keep their meaning; neither is evidence a decision rests
 * on.
 */
function warningProjectionFromCase(
  warning: UserAuthorityJsonMap,
  abnormality: UserAuthorityJsonMap,
): UserAuthorityJsonMap {
  const issueOrigin = warning.sourceType === "issue";
  const references = new Map(
    (parseAffectedAssetHierarchyRefs(
      abnormality.affectedAssetHierarchyRefs,
      existingAssets(abnormality.affectedAssets),
    ) ?? []).map((reference) => [
      assetIdentity(reference),
      reference.assetHierarchyRef,
    ]),
  );
  const affectedAssets = existingAssets(abnormality.affectedAssets)
    .map((asset) => {
      const identity = {
        assetType: asset.assetType,
        assetNumber: asset.assetNumber,
      };
      // An issue warning records the governed reference beside the subject, so
      // repairing it must not drop the component the case points at.
      const reference = references.get(assetIdentity(asset));
      return issueOrigin && reference != null ?
        {...identity, assetHierarchyRef: reference} : identity;
    });
  return {
    ...(issueOrigin ? {} : {
      sourceVersion: abnormality.version,
      sourceSummary: abnormality.abnormalityTypeTitle,
    }),
    sourceSeverity: warningSeverityForCase(warning, abnormality),
    warningReason: abnormality.observedReason,
    affectedAssets,
    component: abnormality.component ?? null,
  };
}

// Quality adjudication compares a warning with its current abnormality, so any
// difference here would strand the case.
function warningProjectionStale(
  warning: UserAuthorityJsonMap,
  abnormality: UserAuthorityJsonMap,
): boolean {
  const projection = warningProjectionFromCase(warning, abnormality);
  return Object.keys(projection).some((field) => {
    // The source version follows the case on every write; on its own it is not
    // a reason to rewrite a warning that already says the same thing.
    if (field === "sourceVersion") return false;
    // Subjects name a set, so a warning listing them in another order already
    // says the same thing and is left exactly as it was written.
    if (field === "affectedAssets") {
      return stableJson(decisionSubjects(projection)) !==
        stableJson(decisionSubjects(warning));
    }
    return stableJson(projection[field]) !== stableJson(warning[field] ?? null);
  });
}

function mergeAffectedAssetHierarchyRefs({
  affectedAssets,
  existing,
  requested,
}: {
  readonly affectedAssets: ReadonlyArray<AffectedAsset>;
  readonly existing: ReadonlyArray<AffectedAssetHierarchyReference>;
  readonly requested:
    ReadonlyArray<AffectedAssetHierarchyReference> | null;
}): ReadonlyArray<AffectedAssetHierarchyReference> {
  const existingByIdentity = new Map(
    existing.map((reference) => [assetIdentity(reference), reference]),
  );
  const requestedByIdentity = new Map(
    (requested ?? []).map((reference) => [
      assetIdentity(reference),
      reference,
    ]),
  );

  return affectedAssets
    .map((asset) => {
      const identity = assetIdentity(asset);
      return requestedByIdentity.get(identity) ??
        existingByIdentity.get(identity) ??
        null;
    })
    .filter(
      (reference): reference is AffectedAssetHierarchyReference =>
        reference != null,
    );
}

function fingerprint(value: unknown): string {
  return `abnreq1-sha256:${
    createHash("sha256")
      .update(JSON.stringify(value), "utf8")
      .digest("hex")
  }`;
}

function parseUpdate(
  raw: UserAuthorityJsonMap,
): ParsedChargeAbnormalityUpdate {
  const reannealingStatus = enumValue(
    raw.reannealingStatus,
    "reannealingStatus",
    REANNEALING_STATUSES,
  );
  const reannealedToChargeNo = optionalPositiveSafeInteger(
    raw.reannealedToChargeNo,
    "reannealedToChargeNo",
  );
  if (reannealedToChargeNo != null &&
      !isFiveDigitChargeNumber(reannealedToChargeNo)) {
    return invalidField(
      "reannealedToChargeNo",
      "reannealedToChargeNo must contain exactly five digits.",
      "charge-number-invalid",
    );
  }
  if (
    (reannealingStatus === "completed") !==
    (reannealedToChargeNo != null)
  ) {
    return invalidField(
      "reannealingStatus",
      "completed re-annealing requires a target charge, and a target charge requires completed status.",
      "inconsistent-reannealing-state",
    );
  }

  const parsedAffectedAssets = parseAffectedAssets(raw.affectedAssets);
  return {
    abnormalityTypeId: cleanDocumentId(
      raw.abnormalityTypeId,
      "abnormalityTypeId",
    ),
    severity: enumValue(raw.severity, "severity", SEVERITIES),
    affectedAssets: identityOnlyAffectedAssets(parsedAffectedAssets),
    affectedAssetHierarchyRefs: parseAffectedAssetHierarchyRefs(
      raw.affectedAssetHierarchyRefs,
      parsedAffectedAssets,
    ),
    component: cleanOptionalString(raw.component, "component", 200),
    observedReason: cleanRequiredString(
      raw.observedReason,
      "observedReason",
      2000,
    ),
    description: cleanOptionalString(raw.description, "description", 4000),
    possibleRootReasonCategory: enumValue(
      raw.possibleRootReasonCategory,
      "possibleRootReasonCategory",
      ROOT_REASON_CATEGORIES,
    ),
    possibleRootReasonNotes: cleanOptionalString(
      raw.possibleRootReasonNotes,
      "possibleRootReasonNotes",
      4000,
    ),
    reannealingStatus,
    reannealedToChargeNo,
  };
}

function parseAbnormalityCreation(
  raw: unknown, abnormalityId: string,
): UserAuthorityJsonMap {
  if (raw == null || typeof raw !== "object" || Array.isArray(raw)) {
    return invalidField("abnormality", "Creation requires an abnormality record.");
  }
  const data = raw as UserAuthorityJsonMap;
  if (Object.prototype.hasOwnProperty.call(data, "_globalPullServerUpdatedAt")) {
    return invalidField("abnormality", "Server clock fields cannot be supplied.");
  }
  try {
    if (!validIsoTimestamp(data.loggedAt) || !validIsoTimestamp(data.updatedAt)) {
      return invalidField("abnormality", "Creation requires ISO text timestamps.");
    }
    const valid = validateExistingAbnormality(data, abnormalityId);
    if (valid.isDeleted !== false || valid.linkedTicketFirestoreId != null ||
        valid.linkedExecutionFirestoreId != null) {
      return invalidField("abnormality",
        "Standalone creation cannot import a deletion or a linked workflow case.");
    }
    const assets = existingAssets(valid.affectedAssets);
    const refs = parseAffectedAssetHierarchyRefs(valid.affectedAssetHierarchyRefs, assets);
    if (data.affectedAssetHierarchyRefs != null && assets.length === 0) {
      return invalidField("affectedAssets", "Select at least one affected asset.");
    }
    return {...valid, version: 1, affectedAssets: identityOnlyAffectedAssets(assets),
      ...(refs == null ? {} : {affectedAssetHierarchyRefs: refs})};
  } catch (error) {
    if (error instanceof ChargeAbnormalityMutationError) {
      throw new ChargeAbnormalityMutationError("invalid-argument", error.message,
        {reasonCode: "abnormality-create-payload-invalid", ...refusalCause(error)});
    }
    throw error;
  }
}

export function parseChargeAbnormalityMutationRequest(
  raw: UserAuthorityJsonMap,
): ParsedChargeAbnormalityMutationRequest {
  const operationRaw = cleanRequiredString(raw.operation, "operation", 32);
  if (!OPERATIONS.has(operationRaw as ChargeAbnormalityMutationOperation)) {
    return invalidField(
      "operation",
      "operation is not supported.",
      "unsupported-abnormality-operation",
    );
  }
  const operation = operationRaw as ChargeAbnormalityMutationOperation;
  const allowedFields =
    operation === "CREATE" ? new Set([...COMMON_REQUEST_FIELDS, "abnormality"]) :
      operation === "UPDATE" ? UPDATE_REQUEST_FIELDS :
        operation === "RECONCILE_QUALITY_CASE" ? RECONCILE_REQUEST_FIELDS :
          COMMON_REQUEST_FIELDS;
  for (const key of Object.keys(raw)) {
    if (!allowedFields.has(key)) {
      throw new ChargeAbnormalityMutationError(
        "invalid-argument",
        "Charge-abnormality mutation request contains an unsupported field.",
        {reasonCode: "unsupported-request-field", field: key},
      );
    }
  }

  const requestId = cleanRequiredString(raw.requestId, "requestId", 64);
  if (!REQUEST_ID_PATTERN.test(requestId)) {
    return invalidField(
      "requestId",
      "requestId must be a canonical UUID.",
      "invalid-request-id",
    );
  }
  const abnormalityId = cleanDocumentId(raw.abnormalityId, "abnormalityId");
  const expectedVersion = operation === "CREATE" && raw.expectedVersion === 0 ?
    0 : positiveSafeInteger(raw.expectedVersion, "expectedVersion");
  if (operation === "CREATE" && expectedVersion !== 0) {
    return invalidField("expectedVersion", "Creation requires expectedVersion zero.");
  }
  const reason = cleanRequiredString(raw.reason, "reason", 500);
  const update = operation === "UPDATE" ? parseUpdate(raw) : null;
  // A repair names the revision of both records it reviewed, so it cannot be
  // applied to a case that moved on in between.
  const expectedWarningVersion = operation === "RECONCILE_QUALITY_CASE" ?
    positiveSafeInteger(raw.expectedWarningVersion, "expectedWarningVersion") :
    undefined;
  const creation = operation === "CREATE" ?
    parseAbnormalityCreation(raw.abnormality, abnormalityId) : undefined;
  const canonicalPayload = {
    requestId,
    abnormalityId,
    operation,
    expectedVersion,
    reason,
    ...(update ?? {}),
    ...(creation == null ? {} : {creation}),
    ...(expectedWarningVersion == null ? {} : {expectedWarningVersion}),
  };
  return {
    requestId,
    abnormalityId,
    operation,
    expectedVersion,
    reason,
    update,
    ...(creation == null ? {} : {creation}),
    ...(expectedWarningVersion == null ? {} : {expectedWarningVersion}),
    payloadFingerprint: fingerprint(canonicalPayload),
  };
}

export function userCanMutateChargeAbnormality(
  data: UserAuthorityJsonMap | null | undefined,
  operation: unknown = "UPDATE",
): boolean {
  const authority = canonicalApprovedUserAuthority(data);
  return authority != null && (operation === "CREATE" ?
    ["admin", "si", "contractSupervisor", "shiftSupervisor", "operations"].some((role) =>
      authority.roles.has(role)) : authority.roles.has("admin"));
}

function requireActor(
  snapshot: ChargeAbnormalityMutationDocumentSnapshotLike,
  actorUid: string,
  operation: ChargeAbnormalityMutationOperation = "UPDATE",
): {readonly name: string} {
  const data = snapshot.exists ? snapshot.data() ?? {} : {};
  if (!userCanMutateChargeAbnormality(data, operation)) {
    throw new ChargeAbnormalityMutationError(
      "permission-denied",
      operation === "CREATE" ? "Approved Operations authority is required." :
        "Approved Admin authority is required.",
      {reasonCode: operation === "CREATE" ? "approved-operations-required" :
        "approved-admin-required"},
    );
  }
  const name =
    typeof data.name === "string" && data.name.trim().length > 0 ?
      data.name.trim() :
      actorUid;
  return {name};
}

function validIsoTimestamp(value: unknown): value is string {
  return typeof value === "string" &&
    value.trim().length > 0 &&
    isValidPersistedInstant(value);
}

function validServerTimestamp(value: unknown): boolean {
  return isValidPersistedInstant(value);
}

function serverTimestampMillis(value: unknown): number {
  return persistedInstantMillis(value);
}

// Preserve stored timestamp types; only the callable response needs ISO text.
function abnormalityForReceipt(data: UserAuthorityJsonMap): UserAuthorityJsonMap {
  const result = {...data};
  for (const field of ["loggedAt", "updatedAt", "deletedAt", "_globalPullServerUpdatedAt"]) {
    const value = data[field];
    if (value == null || typeof value === "string") continue;
    const timestamp = value as {
      seconds?: number;
      nanoseconds?: number;
      _seconds?: number;
      _nanoseconds?: number;
    };
    // Audit snapshots hold a Timestamp in its JSON form (`_seconds`).
    const seconds = timestamp.seconds ?? timestamp._seconds;
    const nanoseconds = timestamp.nanoseconds ?? timestamp._nanoseconds;
    if (Number.isSafeInteger(seconds) && Number.isSafeInteger(nanoseconds)) {
      const fraction = String(nanoseconds).padStart(9, "0")
        .replace(/(000){1,2}$/, "");
      result[field] = new Date((seconds as number) * 1000).toISOString()
        .replace(".000Z", `.${fraction}Z`);
    } else {
      result[field] = new Date(persistedInstantMillis(value)).toISOString();
    }
  }
  return result;
}

function malformedExisting(
  message: string,
  field?: string,
  causeReasonCode?: string,
): never {
  throw new ChargeAbnormalityMutationError(
    "failed-precondition",
    message,
    {
      reasonCode: "abnormality-record-malformed",
      ...(field == null ? {} : {field}),
      ...(causeReasonCode == null ? {} : {causeReasonCode}),
    },
  );
}

// The most specific reason carried by a nested validation refusal, so a
// wrapped refusal still says why (for example, a duplicated reference).
function refusalCause(error: ChargeAbnormalityMutationError): {
  readonly field?: string;
  readonly causeReasonCode?: string;
} {
  const details = (error.details ?? {}) as {
    readonly reasonCode?: unknown;
    readonly causeReasonCode?: unknown;
    readonly field?: unknown;
  };
  const cause = typeof details.causeReasonCode === "string" ?
    details.causeReasonCode : details.reasonCode;
  return {
    ...(typeof details.field === "string" ? {field: details.field} : {}),
    ...(typeof cause === "string" ? {causeReasonCode: cause} : {}),
  };
}

function validateExistingAbnormality(
  data: UserAuthorityJsonMap,
  abnormalityId: string,
  allowLegacyAbsentOptionalKeys = false,
): UserAuthorityJsonMap {
  for (const key of Object.keys(data)) {
    if (!ABNORMALITY_FIELDS.has(key)) {
      return malformedExisting(
        "The charge-abnormality record contains an unsupported field.",
        key,
      );
    }
  }
  for (const field of REQUIRED_ABNORMALITY_FIELDS) {
    if (allowLegacyAbsentOptionalKeys &&
        LEGACY_NULLABLE_ABNORMALITY_FIELDS.has(field)) {
      continue;
    }
    if (!Object.prototype.hasOwnProperty.call(data, field)) {
      return malformedExisting(
        "The charge-abnormality record is incomplete.",
        field,
      );
    }
  }
  if (data.firestoreId !== abnormalityId) {
    return malformedExisting(
      "The charge-abnormality identity does not match its document.",
      "firestoreId",
    );
  }
  positiveExistingInteger(data.sourceChargeNo, "sourceChargeNo");
  if (!isFiveDigitChargeNumber(data.sourceChargeNo)) {
    throw new ChargeAbnormalityMutationError(
      "data-loss",
      "The charge-abnormality sourceChargeNo value is malformed.",
      {reasonCode: "charge-number-invalid", field: "sourceChargeNo"},
    );
  }
  positiveExistingInteger(data.version, "version");
  requiredExistingString(data.abnormalityTypeId, "abnormalityTypeId", 512);
  requiredExistingString(
    data.abnormalityTypeTitle,
    "abnormalityTypeTitle",
    500,
  );
  requiredExistingString(
    data.abnormalityTypeCode,
    "abnormalityTypeCode",
    160,
  );
  existingEnum(data.category, "category", CATEGORIES);
  existingEnum(data.severity, "severity", SEVERITIES);
  const affectedAssets = existingAssets(data.affectedAssets);
  existingAssetHierarchyRefs(
    data.affectedAssetHierarchyRefs,
    affectedAssets,
  );
  requiredExistingString(data.observedReason, "observedReason", 2000);
  requiredExistingString(data.loggedByUid, "loggedByUid", 512);
  requiredExistingString(data.updatedByUid, "updatedByUid", 512);
  if (!validServerTimestamp(data.loggedAt)) {
    return malformedExisting(
      "The charge-abnormality loggedAt value is malformed.",
      "loggedAt",
    );
  }
  if (!validServerTimestamp(data.updatedAt)) {
    return malformedExisting(
      "The charge-abnormality updatedAt value is malformed.",
      "updatedAt",
    );
  }
  const loggedAtMillis = persistedInstantMillis(data.loggedAt);
  const updatedAtMillis = persistedInstantMillis(data.updatedAt);
  if (updatedAtMillis < loggedAtMillis) {
    return malformedExisting(
      "The charge-abnormality updatedAt value precedes loggedAt.",
      "updatedAt",
    );
  }
  if (data._globalPullServerUpdatedAt != null &&
      !validServerTimestamp(data._globalPullServerUpdatedAt)) {
    return malformedExisting(
      "The charge-abnormality server clock value is malformed.",
      "_globalPullServerUpdatedAt",
    );
  }
  if (typeof data.isDeleted !== "boolean") {
    return malformedExisting(
      "The charge-abnormality deletion state is malformed.",
      "isDeleted",
    );
  }
  validateExistingOptionalFields(data);
  return {...data};
}

function requiredExistingString(
  value: unknown,
  field: string,
  maxLength: number,
): void {
  if (
    typeof value !== "string" ||
    value.trim().length === 0 ||
    value.trim().length > maxLength
  ) {
    malformedExisting(
      `The charge-abnormality ${field} value is malformed.`,
      field,
    );
  }
}

function optionalExistingString(
  value: unknown,
  field: string,
  maxLength: number,
): void {
  if (
    value != null &&
    (
      typeof value !== "string" ||
      value.trim().length === 0 ||
      value.trim().length > maxLength
    )
  ) {
    malformedExisting(
      `The charge-abnormality ${field} value is malformed.`,
      field,
    );
  }
}

function positiveExistingInteger(value: unknown, field: string): void {
  if (!Number.isSafeInteger(value) || (value as number) <= 0) {
    malformedExisting(
      `The charge-abnormality ${field} value is malformed.`,
      field,
    );
  }
}

function existingEnum(
  value: unknown,
  field: string,
  allowed: ReadonlySet<string>,
): void {
  if (typeof value !== "string" || !allowed.has(value)) {
    malformedExisting(
      `The charge-abnormality ${field} value is malformed.`,
      field,
    );
  }
}

function existingAssets(value: unknown): ReadonlyArray<AffectedAsset> {
  try {
    // Older pilot builds allowed an empty affected-assets list. Continue to
    // read and repair those rows while requiring all new/update payloads to
    // identify at least one asset.
    return parseAffectedAssets(value, {allowEmpty: true});
  } catch (error) {
    if (error instanceof ChargeAbnormalityMutationError) {
      malformedExisting(
        "The charge-abnormality affectedAssets value is malformed.",
        "affectedAssets",
        refusalCause(error).causeReasonCode,
      );
    }
    throw error;
  }
}

function existingAssetHierarchyRefs(
  value: unknown,
  affectedAssets: ReadonlyArray<AffectedAsset>,
): void {
  try {
    parseAffectedAssetHierarchyRefs(value, affectedAssets);
  } catch (error) {
    if (error instanceof ChargeAbnormalityMutationError) {
      malformedExisting(
        "The charge-abnormality affectedAssetHierarchyRefs value is malformed.",
        "affectedAssetHierarchyRefs",
        refusalCause(error).causeReasonCode,
      );
    }
    throw error;
  }
}

function validateExistingOptionalFields(data: UserAuthorityJsonMap): void {
  optionalExistingString(data.component, "component", 200);
  optionalExistingString(data.description, "description", 4000);
  optionalExistingString(
    data.possibleRootReasonNotes,
    "possibleRootReasonNotes",
    4000,
  );
  optionalExistingString(data.loggedByName, "loggedByName", 500);
  optionalExistingString(data.updatedByName, "updatedByName", 500);
  optionalExistingString(
    data.linkedTicketFirestoreId,
    "linkedTicketFirestoreId",
    512,
  );
  optionalExistingString(
    data.linkedExecutionFirestoreId,
    "linkedExecutionFirestoreId",
    512,
  );
  optionalExistingString(data.deletedByUid, "deletedByUid", 512);
  optionalExistingString(data.deletedByName, "deletedByName", 500);
  optionalExistingString(data.deleteReason, "deleteReason", 500);
  if (
    data.deletedAt != null &&
    !validServerTimestamp(data.deletedAt)
  ) {
    malformedExisting(
      "The charge-abnormality deletedAt value is malformed.",
      "deletedAt",
    );
  }
  if (
    data.possibleRootReasonCategory != null
  ) {
    existingEnum(
      data.possibleRootReasonCategory,
      "possibleRootReasonCategory",
      ROOT_REASON_CATEGORIES,
    );
  } else {
    malformedExisting(
      "The charge-abnormality possibleRootReasonCategory value is malformed.",
      "possibleRootReasonCategory",
    );
  }
  if (data.reannealingStatus != null) {
    existingEnum(
      data.reannealingStatus,
      "reannealingStatus",
      REANNEALING_STATUSES,
    );
  } else {
    malformedExisting(
      "The charge-abnormality reannealingStatus value is malformed.",
      "reannealingStatus",
    );
  }
  if (
    data.reannealedToChargeNo != null &&
    (
      !Number.isSafeInteger(data.reannealedToChargeNo) ||
      !isFiveDigitChargeNumber(data.reannealedToChargeNo)
    )
  ) {
    malformedExisting(
      "The charge-abnormality reannealedToChargeNo value is malformed.",
      "reannealedToChargeNo",
    );
  }
  const completed = data.reannealingStatus === "completed";
  const hasTarget = data.reannealedToChargeNo != null;
  if (
    completed !== hasTarget ||
    data.reannealedToChargeNo === data.sourceChargeNo
  ) {
    malformedExisting(
      "The charge-abnormality re-annealing state is inconsistent.",
      "reannealingStatus",
    );
  }
  if (data.isDeleted === false) {
    if (
      data.deletedAt != null ||
      data.deletedByUid != null ||
      data.deletedByName != null ||
      data.deleteReason != null
    ) {
      malformedExisting(
        "An active charge abnormality contains deletion metadata.",
        "isDeleted",
      );
    }
  } else {
    if (
      !validServerTimestamp(data.deletedAt) ||
      typeof data.deletedByUid !== "string" ||
      data.deletedByUid.trim().length === 0 ||
      typeof data.deletedByName !== "string" ||
      data.deletedByName.trim().length === 0 ||
      typeof data.deleteReason !== "string" ||
      data.deleteReason.trim().length === 0
    ) {
      malformedExisting(
        "A deleted charge abnormality is missing deletion metadata.",
        "isDeleted",
      );
    }
    const deletedAtMillis = persistedInstantMillis(data.deletedAt);
    const loggedAtMillis = persistedInstantMillis(data.loggedAt);
    const updatedAtMillis = persistedInstantMillis(data.updatedAt);
    if (deletedAtMillis < loggedAtMillis ||
        deletedAtMillis > updatedAtMillis) {
      malformedExisting(
        "The charge-abnormality deletedAt value falls outside its lifecycle.",
        "deletedAt",
      );
    }
  }
}

function canonicalType(
  snapshot: ChargeAbnormalityMutationDocumentSnapshotLike,
  typeId: string,
): {readonly code: string; readonly title: string; readonly category: string} {
  if (!snapshot.exists) {
    throw new ChargeAbnormalityMutationError(
      "failed-precondition",
      "The selected abnormality type does not exist.",
      {reasonCode: "abnormality-type-missing", abnormalityTypeId: typeId},
    );
  }
  const data = snapshot.data() ?? {};
  if (
    data.firestoreId !== typeId ||
    data.isActive !== true ||
    data.isDeleted !== false
  ) {
    throw new ChargeAbnormalityMutationError(
      "failed-precondition",
      "The selected abnormality type is inactive or malformed.",
      {reasonCode: "abnormality-type-invalid", abnormalityTypeId: typeId},
    );
  }
  try {
    const code = cleanRequiredString(data.code, "type.code", 160);
    const title = cleanRequiredString(data.title, "type.title", 500);
    const category = enumValue(data.category, "type.category", CATEGORIES);
    enumValue(data.severity, "type.severity", SEVERITIES);
    return {code, title, category};
  } catch (error) {
    if (error instanceof ChargeAbnormalityMutationError) {
      throw new ChargeAbnormalityMutationError(
        "failed-precondition",
        "The selected abnormality type is inactive or malformed.",
        {reasonCode: "abnormality-type-invalid", abnormalityTypeId: typeId},
      );
    }
    throw error;
  }
}

function warningAfterAbnormalityUpdate(args: {
  beforeAbnormality: UserAuthorityJsonMap;
  afterAbnormality: UserAuthorityJsonMap;
  warning: UserAuthorityJsonMap;
  warningId: string;
  linkedTicketId: string | null;
  actorUid: string;
  actorName: string;
  requestId: string;
  reason: string;
  committedAt: unknown;
}): UserAuthorityJsonMap | null {
  const {
    beforeAbnormality,
    afterAbnormality,
    warning,
    warningId,
    linkedTicketId,
  } = args;
  const raChanged =
    beforeAbnormality.reannealingStatus !== afterAbnormality.reannealingStatus ||
    beforeAbnormality.reannealedToChargeNo !==
      afterAbnormality.reannealedToChargeNo;
  // Refresh from the committed abnormality rather than from this write's diff,
  // so a projection that drifted earlier is repaired by the next governed
  // update. Creation actor and time are never rewritten here.
  const projectionStale = warningProjectionStale(warning, afterAbnormality);
  if (!raChanged && !projectionStale) return null;

  if (serverTimestampMillis(args.committedAt) <
      serverTimestampMillis(warning.updatedAt)) {
    throw new ChargeAbnormalityMutationError(
      "aborted",
      "The server clock precedes the linked warning update. Retry after the recorded time boundary.",
      {reasonCode: "charge-quality-warning-clock-regression"},
    );
  }

  const nextVersion = (warning.version as number) + 1;
  if (!Number.isSafeInteger(nextVersion)) {
    throw new ChargeAbnormalityMutationError(
      "failed-precondition",
      "The linked quality-warning version cannot advance safely.",
      {reasonCode: "charge-quality-warning-version-overflow"},
    );
  }
  // An earlier decision covered the evidence as the warning recorded it. If
  // repairing that drift changes what the case is about, the decision is
  // returned for review rather than silently extended to evidence it never
  // saw. The decision itself stays in the quality audit as history, exactly
  // as a reopen leaves it.
  const after: UserAuthorityJsonMap = {...warning};
  if (projectionStale) {
    const decisionOutgrown = warning.status !== "open" &&
      warningDecisionBasisStale(warning, afterAbnormality);
    Object.assign(after, warningProjectionFromCase(warning, afterAbnormality), {
      ...(decisionOutgrown ? {
        status: "open",
        closureRequestReason: null,
        closureRequestedAt: null,
        closureRequestedByUid: null,
        closureRequestedByName: null,
        closedAt: null,
        closedByUid: null,
        closedByName: null,
        closureDisposition: null,
        linkedReannealingChargeNos: [],
        decisionReason: null,
      } : {}),
    });
  }
  if (raChanged) {
    if (afterAbnormality.reannealingStatus === "completed") {
      if (beforeAbnormality.reannealingStatus !== "required" &&
          beforeAbnormality.reannealingStatus !== "completed") {
        throw new ChargeAbnormalityMutationError(
          "failed-precondition",
          "Re-annealing completion requires a prior RA-required decision.",
          {reasonCode: "charge-quality-ra-not-required"},
        );
      }
    }
    if (afterAbnormality.reannealingStatus === "notRequired" ||
        afterAbnormality.reannealingStatus === "completed") {
      Object.assign(after, {
        status: "closureRequested",
        closureRequestReason: args.reason,
        closureRequestedAt: args.committedAt,
        closureRequestedByUid: args.actorUid,
        closureRequestedByName: args.actorName,
        closedAt: null,
        closedByUid: null,
        closedByName: null,
        closureDisposition: null,
        linkedReannealingChargeNos: [],
        decisionReason: null,
      });
    } else {
      Object.assign(after, {
        status: "open",
        closureRequestReason: null,
        closureRequestedAt: null,
        closureRequestedByUid: null,
        closureRequestedByName: null,
        closedAt: null,
        closedByUid: null,
        closedByName: null,
        closureDisposition: null,
        linkedReannealingChargeNos: [],
        decisionReason: null,
      });
    }
  }
  Object.assign(after, {
    updatedAt: args.committedAt,
    updatedByUid: args.actorUid,
    updatedByName: args.actorName,
    version: nextVersion,
    lastMutationId: args.requestId,
  });
  return validateQualityWarningRecord(after, warningId);
}

function replayResult(args: {
  request: ParsedChargeAbnormalityMutationRequest;
  actorUid: string;
  receipt: UserAuthorityJsonMap;
  abnormality: UserAuthorityJsonMap;
  audit: UserAuthorityJsonMap | null;
  warning: UserAuthorityJsonMap | null;
  warningId: string;
  auditId: string;
}): ChargeAbnormalityMutationResult {
  const {
    request,
    actorUid,
    receipt,
    abnormality,
    audit,
    warning,
    warningId,
    auditId,
  } = args;
  if (
    receipt.payloadFingerprint !== request.payloadFingerprint ||
    receipt.actorUid !== actorUid ||
    receipt.abnormalityId !== request.abnormalityId
  ) {
    throw new ChargeAbnormalityMutationError(
      "aborted",
      "requestId is already bound to a different abnormality mutation.",
      {reasonCode: "abnormality-request-id-conflict"},
    );
  }
  if (audit == null) {
    throw new ChargeAbnormalityMutationError(
      "data-loss",
      "The abnormality mutation receipt exists without its immutable audit.",
      {reasonCode: "abnormality-audit-missing"},
    );
  }
  const current = validateExistingAbnormality(
    abnormality,
    request.abnormalityId,
  );
  const resultVersion = receipt.resultVersion;
  const committedAt = receipt.committedAtIso;
  if (
    receipt.schemaVersion !== 1 ||
    receipt.requestId !== request.requestId ||
    receipt.operation !== request.operation ||
    receipt.expectedVersion !== request.expectedVersion ||
    receipt.auditId !== auditId ||
    !Number.isSafeInteger(resultVersion) ||
    !validIsoTimestamp(committedAt) ||
    audit.schemaVersion !== 1 ||
    audit.eventType !== "chargeAbnormalityMutation" ||
    audit.requestId !== request.requestId ||
    audit.performedByUid !== actorUid ||
    audit.entityId !== request.abnormalityId ||
    audit.operation !== request.operation ||
    audit.resultVersion !== resultVersion
  ) {
    return replayEvidenceMalformed();
  }
  // The receipt proves what was accepted. Later legitimate work may advance
  // the abnormality or its warning, but neither may fall behind that result.
  const hasWarningEvidence = Object.prototype.hasOwnProperty.call(
    receipt,
    "linkedWarningId",
  ) || Object.prototype.hasOwnProperty.call(
    receipt,
    "linkedWarningVersion",
  );
  if (hasWarningEvidence &&
      (warning == null ||
        receipt.linkedWarningId !== warningId ||
        !Number.isSafeInteger(receipt.linkedWarningVersion) ||
        (warning.version as number) <
          (receipt.linkedWarningVersion as number))) {
    throw new ChargeAbnormalityMutationError(
      "data-loss",
      "The linked quality-warning replay evidence has drifted.",
      {reasonCode: "abnormality-replay-warning-drift"},
    );
  }
  if ((current.version as number) < (resultVersion as number)) {
    return replayEvidenceDrift();
  }
  if (receipt.acceptedEvidenceVersion === 2 &&
      (typeof receipt.acceptedAuditSha256 !== "string" ||
        receipt.acceptedAuditSha256 !== acceptedAuditDigest(audit))) {
    return replayEvidenceMalformed();
  }
  // The accepted content is always re-derived from the immutable audit and
  // bound to this frozen command, whether or not the record has moved on.
  const accepted = acceptedAbnormalityFromAudit({
    audit,
    current,
    request,
    actorUid,
    resultVersion: resultVersion as number,
    committedAt: committedAt as string,
  });
  if (current.version === resultVersion &&
      !abnormalityRecordsMatch(accepted, current)) {
    return replayEvidenceDrift();
  }
  return {
    ok: true,
    requestId: request.requestId,
    abnormalityId: request.abnormalityId,
    operation: request.operation,
    version: resultVersion as number,
    auditId,
    committedAt: committedAt as string,
    idempotentReplay: true,
    abnormality: abnormalityForReceipt(accepted),
  };
}

function replayEvidenceMalformed(): never {
  throw new ChargeAbnormalityMutationError(
    "data-loss",
    "The abnormality mutation receipt or audit is malformed.",
    {reasonCode: "abnormality-replay-evidence-malformed"},
  );
}

function replayEvidenceDrift(): never {
  throw new ChargeAbnormalityMutationError(
    "data-loss",
    "The charge abnormality no longer matches the recorded mutation.",
    {reasonCode: "abnormality-replay-evidence-drift"},
  );
}

const ABNORMALITY_DATE_FIELDS = new Set([
  "loggedAt",
  "updatedAt",
  "deletedAt",
]);

const SERVER_AUTHORED_CREATE_FIELDS = new Set([
  "abnormalityTypeTitle",
  "abnormalityTypeCode",
  "category",
  "updatedAt",
  "updatedByUid",
  "updatedByName",
]);

const ACCEPTED_CASE_IDENTITY_FIELDS = [
  "sourceChargeNo",
  "loggedByUid",
  "loggedByName",
  "linkedTicketFirestoreId",
  "linkedExecutionFirestoreId",
];

function acceptedAuditDigest(audit: UserAuthorityJsonMap): string {
  const {timestamp: _timestamp, ...evidence} = audit;
  return createHash("sha256")
    .update(stableJson(evidence), "utf8")
    .digest("hex");
}

// A stored Firestore timestamp and its audited JSON form name the same moment,
// but the stored form truncates below the millisecond. Compare at the
// precision both forms carry.
function sameInstant(left: unknown, right: unknown): boolean {
  const first = persistedInstantMillis(left);
  const second = persistedInstantMillis(right);
  return Number.isFinite(first) && Number.isFinite(second) &&
    Math.floor(first) === Math.floor(second);
}

// Two views of one accepted record. A stored instant and its audited JSON form
// differ in shape, so instants are compared by the moment they name.
function abnormalityRecordsMatch(
  expected: UserAuthorityJsonMap,
  actual: UserAuthorityJsonMap,
): boolean {
  const keys = new Set([...Object.keys(expected), ...Object.keys(actual)]);
  for (const key of keys) {
    if (key === "_globalPullServerUpdatedAt") continue;
    // An absent optional key and an explicit null describe the same absence.
    const left = expected[key] ?? null;
    const right = actual[key] ?? null;
    if (ABNORMALITY_DATE_FIELDS.has(key)) {
      if (left == null || right == null) {
        if (left != null || right != null) return false;
        continue;
      }
      if (!sameInstant(left, right)) return false;
      continue;
    }
    if (stableJson(left) !== stableJson(right)) return false;
  }
  return true;
}

function auditSnapshotRecord(
  value: unknown,
  abnormalityId: string,
  repeatedReferencesRepaired = false,
): UserAuthorityJsonMap {
  let snapshot: unknown = null;
  try {
    if (typeof value === "string") snapshot = JSON.parse(value);
  } catch (_) {
    snapshot = null;
  }
  if (snapshot == null || typeof snapshot !== "object" ||
      Array.isArray(snapshot)) {
    return replayEvidenceMalformed();
  }
  try {
    const record = snapshot as UserAuthorityJsonMap;
    return validateExistingAbnormality(
      repeatedReferencesRepaired ?
        collapseRepeatedHierarchyReferences(record).record : record,
      abnormalityId,
      true,
    );
  } catch (error) {
    if (error instanceof ChargeAbnormalityMutationError) {
      return replayEvidenceMalformed();
    }
    throw error;
  }
}

// Recomputes the committed record from the audited pre-image and the frozen
// command, so only server-authored fields are taken on trust.
function expectedAcceptedAbnormality(args: {
  before: UserAuthorityJsonMap;
  accepted: UserAuthorityJsonMap;
  request: ParsedChargeAbnormalityMutationRequest;
  actorUid: string;
}): UserAuthorityJsonMap {
  const {before, accepted, request, actorUid} = args;
  const expected: UserAuthorityJsonMap = {
    ...before,
    ...canonicalNullableGaps(before),
  };
  const update = request.update;
  if (request.operation === "RECONCILE_QUALITY_CASE") {
    Object.assign(
      expected,
      collapseRepeatedHierarchyReferences(expected).record,
    );
  } else if (update != null) {
    const existingRefs = parseAffectedAssetHierarchyRefs(
      before.affectedAssetHierarchyRefs,
      existingAssets(before.affectedAssets),
    ) ?? [];
    const sameType = update.abnormalityTypeId === before.abnormalityTypeId;
    Object.assign(expected, {
      abnormalityTypeId: update.abnormalityTypeId,
      abnormalityTypeTitle: sameType ?
        before.abnormalityTypeTitle : accepted.abnormalityTypeTitle,
      abnormalityTypeCode: sameType ?
        before.abnormalityTypeCode : accepted.abnormalityTypeCode,
      category: sameType ? before.category : accepted.category,
      severity: update.severity,
      affectedAssets: update.affectedAssets,
      affectedAssetHierarchyRefs: mergeAffectedAssetHierarchyRefs({
        affectedAssets: update.affectedAssets,
        existing: existingRefs,
        requested: update.affectedAssetHierarchyRefs,
      }),
      component: update.component,
      observedReason: update.observedReason,
      description: update.description,
      possibleRootReasonCategory: update.possibleRootReasonCategory,
      possibleRootReasonNotes: update.possibleRootReasonNotes,
      reannealingStatus: update.reannealingStatus,
      reannealedToChargeNo: update.reannealedToChargeNo,
    });
  } else {
    Object.assign(expected, {
      isDeleted: true,
      deletedAt: accepted.deletedAt,
      deletedByUid: actorUid,
      deletedByName: accepted.deletedByName,
      deleteReason: request.reason,
    });
  }
  Object.assign(expected, {
    updatedAt: accepted.updatedAt,
    updatedByUid: actorUid,
    updatedByName: accepted.updatedByName,
    version: request.expectedVersion + 1,
  });
  return expected;
}

// The record this request committed, re-derived from the immutable audit and
// bound to the frozen command, so altered evidence cannot be returned as the
// original outcome.
function acceptedAbnormalityFromAudit(args: {
  audit: UserAuthorityJsonMap;
  current: UserAuthorityJsonMap;
  request: ParsedChargeAbnormalityMutationRequest;
  actorUid: string;
  resultVersion: number;
  committedAt: string;
}): UserAuthorityJsonMap {
  const {audit, current, request, actorUid, resultVersion, committedAt} = args;
  const accepted = auditSnapshotRecord(audit.afterJson, request.abnormalityId);
  const deleting = request.operation === "SOFT_DELETE";
  if (resultVersion !== request.expectedVersion + 1 ||
      accepted.version !== resultVersion ||
      accepted.updatedByUid !== actorUid ||
      accepted.updatedByName !== audit.performedByName ||
      accepted.isDeleted !== deleting ||
      !sameInstant(accepted.updatedAt, committedAt)) {
    return replayEvidenceMalformed();
  }
  if (deleting &&
      (accepted.deletedByUid !== actorUid ||
        accepted.deletedByName !== audit.performedByName ||
        accepted.deleteReason !== request.reason ||
        !sameInstant(accepted.deletedAt, committedAt))) {
    return replayEvidenceMalformed();
  }
  if (request.operation === "CREATE") {
    const creation = (request.creation ?? {}) as UserAuthorityJsonMap;
    if (audit.beforeJson !== null ||
        Object.keys(creation).some((field) =>
          !SERVER_AUTHORED_CREATE_FIELDS.has(field) &&
          stableJson(creation[field]) !== stableJson(accepted[field]))) {
      return replayEvidenceMalformed();
    }
  } else {
    const before = auditSnapshotRecord(
      audit.beforeJson,
      request.abnormalityId,
      request.operation === "RECONCILE_QUALITY_CASE",
    );
    if (before.version !== request.expectedVersion ||
        !abnormalityRecordsMatch(
          expectedAcceptedAbnormality({before, accepted, request, actorUid}),
          accepted,
        )) {
      return replayEvidenceMalformed();
    }
  }
  // Later corrections may change observations, never which case was logged.
  if (!sameInstant(accepted.loggedAt, current.loggedAt) ||
      ACCEPTED_CASE_IDENTITY_FIELDS
        .some((field) => accepted[field] !== current[field])) {
    return replayEvidenceDrift();
  }
  return accepted;
}

/**
 * The reviewed repair of a standalone quality case.
 *
 * Ordinary commands refuse a case whose two records disagree, and the quality
 * decisions that would repair it refuse it for the same reason, so a damaged
 * case has no way out. This command is that way out. It authors no evidence:
 * every repaired value is derived from the charge abnormality, which is where a
 * standalone case's evidence comes from. It names the revision of both records
 * it reviewed, keeps the records it found in its audit, and decides explicitly
 * what happens to an earlier decision instead of leaving it to cover evidence
 * it never saw.
 */
function reconcileQualityCase(args: {
  readonly stored: UserAuthorityJsonMap;
  readonly existing: UserAuthorityJsonMap;
  readonly referencesRepaired: boolean;
  readonly warning: UserAuthorityJsonMap;
  readonly warningId: string;
  readonly linkedTicketId: string | null;
  readonly request: ParsedChargeAbnormalityMutationRequest;
  readonly actorUid: string;
  readonly actorName: string;
  readonly auditId: string;
  readonly now: () => Date;
  readonly timestampFromDate: (date: Date) => unknown;
  readonly commit: (records: {
    readonly abnormality: UserAuthorityJsonMap;
    readonly warning: UserAuthorityJsonMap;
    readonly audit: UserAuthorityJsonMap;
    readonly receipt: UserAuthorityJsonMap;
  }) => void;
}): ChargeAbnormalityMutationResult {
  const {
    stored, existing, warning, warningId, request, actorUid, actorName, auditId,
  } = args;
  if (args.linkedTicketId != null) {
    throw new ChargeAbnormalityMutationError(
      "failed-precondition",
      "An issue-origin case is repaired through its maintenance issue.",
      {reasonCode: "charge-quality-case-issue-origin-reconcile-denied"},
    );
  }
  if (warning.version !== request.expectedWarningVersion) {
    throw new ChargeAbnormalityMutationError(
      "aborted",
      "The quality warning changed before this repair was committed.",
      {
        reasonCode: "charge-quality-warning-preimage-mismatch",
        field: "expectedWarningVersion",
        currentVersion: warning.version,
      },
    );
  }
  const committedAtDate = args.now();
  const committedAtIso = committedAtDate.toISOString();
  const committedAt = args.timestampFromDate(committedAtDate);
  if (committedAtDate.valueOf() < persistedInstantMillis(existing.updatedAt) ||
      committedAtDate.valueOf() < serverTimestampMillis(warning.updatedAt)) {
    throw new ChargeAbnormalityMutationError(
      "aborted",
      "The server clock precedes this quality case. Retry after the recorded time boundary.",
      {reasonCode: "charge-abnormality-clock-regression"},
    );
  }
  const resultVersion = request.expectedVersion + 1;
  const warningVersion = (warning.version as number) + 1;
  if (!Number.isSafeInteger(resultVersion) ||
      !Number.isSafeInteger(warningVersion)) {
    throw new ChargeAbnormalityMutationError(
      "failed-precondition",
      "The charge-abnormality version cannot advance safely.",
      {reasonCode: "abnormality-version-overflow"},
    );
  }

  const abnormalityGaps = canonicalNullableGaps(existing);
  const warningGaps = canonicalQualityWarningGaps(warning);
  const creationDrift = !sameInstant(warning.createdAt, existing.loggedAt) ||
    warning.createdByUid !== existing.loggedByUid ||
    (warning.createdByName ?? null) !== (existing.loggedByName ?? null);
  if (!args.referencesRepaired &&
      Object.keys(abnormalityGaps).length === 0 &&
      Object.keys(warningGaps).length === 0 &&
      !warningProjectionStale(warning, existing) &&
      !creationDrift &&
      warning.sourceVersion === existing.version) {
    throw new ChargeAbnormalityMutationError(
      "failed-precondition",
      "This quality case already reads as one case, so nothing was changed.",
      {reasonCode: "charge-quality-case-already-consistent"},
    );
  }

  const after: UserAuthorityJsonMap = {
    ...existing,
    ...abnormalityGaps,
    updatedAt: committedAtIso,
    updatedByUid: actorUid,
    updatedByName: actorName,
    version: resultVersion,
  };
  validateExistingAbnormality(after, request.abnormalityId);

  // An earlier decision covered the evidence the warning recorded. Where the
  // repair changes what the case is about, the decision returns for review and
  // stays in the quality audit as history, exactly as a reopen leaves it.
  const decisionOutgrown = warning.status !== "open" &&
    warningDecisionBasisStale(warning, after);
  const warningAfter: UserAuthorityJsonMap = {
    ...warning,
    ...warningGaps,
    ...warningProjectionFromCase(warning, after),
    createdAt: args.timestampFromDate(
      new Date(persistedInstantMillis(after.loggedAt)),
    ),
    createdByUid: after.loggedByUid,
    createdByName: after.loggedByName,
    updatedAt: committedAt,
    updatedByUid: actorUid,
    updatedByName: actorName,
    version: warningVersion,
    ...(decisionOutgrown ? {
      status: "open",
      closureRequestReason: null,
      closureRequestedAt: null,
      closureRequestedByUid: null,
      closureRequestedByName: null,
      closedAt: null,
      closedByUid: null,
      closedByName: null,
      closureDisposition: null,
      linkedReannealingChargeNos: [],
      decisionReason: null,
    } : {}),
  };
  validateQualityWarningRecord(warningAfter, warningId);
  assertCreatedCaseIsAdjudicable(
    {
      warningId,
      warning: warningAfter,
      abnormalityId: request.abnormalityId,
      abnormality: after,
    },
    "This repair would leave a quality case that still cannot be decided. " +
    "Nothing was changed.",
  );

  const audit: UserAuthorityJsonMap = {
    schemaVersion: 1,
    eventType: "chargeAbnormalityMutation",
    entityType: "charge_abnormality",
    entityId: request.abnormalityId,
    action: "update",
    severity: "high",
    performedByUid: actorUid,
    performedByName: actorName,
    timestamp: committedAt,
    reason: "manualOverride",
    reasonNotes: request.reason,
    summary: "Reconciled charge abnormality and quality warning",
    // The records exactly as they were found, repeats and gaps included.
    beforeJson: JSON.stringify(stored),
    afterJson: JSON.stringify(after),
    requestId: request.requestId,
    operation: request.operation,
    expectedVersion: request.expectedVersion,
    resultVersion,
    linkedWarningId: warningId,
    linkedWarningBeforeVersion: warning.version,
    linkedWarningResultVersion: warningVersion,
    linkedWarningBeforeJson: JSON.stringify(warning),
    linkedWarningAfterJson: JSON.stringify(warningAfter),
    decisionReturnedForReview: decisionOutgrown,
  };
  args.commit({
    abnormality: after,
    warning: warningAfter,
    audit: {...audit},
    receipt: {
      schemaVersion: 1,
      requestId: request.requestId,
      actorUid,
      abnormalityId: request.abnormalityId,
      operation: request.operation,
      payloadFingerprint: request.payloadFingerprint,
      expectedVersion: request.expectedVersion,
      resultVersion,
      linkedWarningId: warningId,
      linkedWarningVersion: warningVersion,
      auditId,
      committedAt,
      committedAtIso,
      acceptedEvidenceVersion: 2,
      acceptedAuditSha256: acceptedAuditDigest(audit),
    },
  });
  return {
    ok: true,
    requestId: request.requestId,
    abnormalityId: request.abnormalityId,
    operation: request.operation,
    version: resultVersion,
    auditId,
    committedAt: committedAtIso,
    idempotentReplay: false,
    abnormality: abnormalityForReceipt(after),
  };
}

export async function mutateChargeAbnormalityWithDb(args: {
  db: ChargeAbnormalityMutationFirestoreLike;
  authUid: string | null;
  data: UserAuthorityJsonMap;
  now?: () => Date;
  timestampFromDate?: (date: Date) => unknown;
  beforeTransactionForTest?: () => Promise<void>;
}): Promise<ChargeAbnormalityMutationResult> {
  const {db, data} = args;
  if (args.authUid == null || args.authUid.trim().length === 0) {
    throw new ChargeAbnormalityMutationError(
      "unauthenticated",
      "Sign in before managing charge abnormalities.",
    );
  }
  const actorUid = args.authUid.trim();
  const request = parseChargeAbnormalityMutationRequest(data);
  const now = args.now ?? (() => new Date());
  const timestampFromDate = args.timestampFromDate ?? ((date: Date) => date);

  const actorRef = db.collection("users").doc(actorUid);
  const abnormalityRef = db
    .collection("charge_abnormalities")
    .doc(request.abnormalityId);
  const receiptRef = db
    .collection("charge_abnormality_mutation_receipts")
    .doc(request.requestId);
  const auditId = `server_charge_abnormality_${request.requestId}`;
  const auditRef = db.collection("audit_logs").doc(auditId);

  requireActor(await actorRef.get(), actorUid, request.operation);
  if (args.beforeTransactionForTest != null) {
    await args.beforeTransactionForTest();
  }

  return db.runTransaction(async (transaction) => {
    const receiptSnapshot = await transaction.get(receiptRef);
    const actorSnapshot = await transaction.get(actorRef);
    const actor = requireActor(actorSnapshot, actorUid, request.operation);
    const abnormalitySnapshot = await transaction.get(abnormalityRef);
    const auditSnapshot = await transaction.get(auditRef);

    if (request.operation === "CREATE") {
      const warningId = `abnormality_${request.abnormalityId}`;
      const warningRef = db.collection("quality_warnings").doc(warningId);
      const warningSnapshot = await transaction.get(warningRef);
      const warning = warningSnapshot.exists ? validateQualityWarningRecord(
        warningSnapshot.data() ?? {}, warningId,
      ) : null;
      if (receiptSnapshot.exists) {
        return replayResult({request, actorUid,
          receipt: receiptSnapshot.data() ?? {},
          abnormality: abnormalitySnapshot.data() ?? {},
          audit: auditSnapshot.exists ? auditSnapshot.data() ?? {} : null,
          warning, warningId, auditId});
      }
      if (abnormalitySnapshot.exists || warningSnapshot.exists || auditSnapshot.exists) {
        throw new ChargeAbnormalityMutationError("aborted",
          "The creation identity already belongs to another recorded case.",
          {reasonCode: "abnormality-create-identity-collision"});
      }
      const creation = request.creation!;
      if (creation.loggedByUid !== actorUid || creation.updatedByUid !== actorUid) {
        throw new ChargeAbnormalityMutationError("permission-denied",
          "Only the original approved author can submit this saved abnormality.",
          {reasonCode: "abnormality-create-author-mismatch"});
      }
      const typeId = cleanDocumentId(creation.abnormalityTypeId, "abnormalityTypeId");
      const type = canonicalType(await transaction.get(
        db.collection("abnormality_types").doc(typeId)), typeId);
      const committedDate = now();
      if (persistedInstantMillis(creation.updatedAt) > committedDate.valueOf()) {
        // Preserve original case identity and chronology; retry once the server
        // clock catches up rather than permanently rejecting a local-first save.
        throw new ChargeAbnormalityMutationError("unavailable",
          "The saved abnormality time is ahead of the server clock. " +
          "It remains saved for retry; check the phone's automatic date and time.",
          {reasonCode: "abnormality-create-future-time"});
      }
      const committedAtIso = committedDate.toISOString();
      const committedAt = timestampFromDate(committedDate);
      const after = validateExistingAbnormality({...creation,
        abnormalityTypeTitle: type.title, abnormalityTypeCode: type.code,
        category: type.category, updatedAt: committedAtIso,
        updatedByUid: actorUid, updatedByName: actor.name,
      }, request.abnormalityId);
      const createdWarning = validateQualityWarningRecord({
        schemaVersion: 1, warningId, sourceType: "abnormality",
        sourceId: request.abnormalityId, sourceVersion: 1,
        sourceChargeNo: after.sourceChargeNo,
        sourceSummary: after.abnormalityTypeTitle, sourceSeverity: after.severity,
        warningReason: after.observedReason, affectedAssets: after.affectedAssets,
        component: after.component, status: "open",
        closureRequestReason: null, closureRequestedAt: null,
        closureRequestedByUid: null, closureRequestedByName: null,
        closedAt: null, closedByUid: null, closedByName: null,
        closureDisposition: null, linkedReannealingChargeNos: [], decisionReason: null,
        createdAt: timestampFromDate(new Date(persistedInstantMillis(after.loggedAt))),
        createdByUid: after.loggedByUid, createdByName: after.loggedByName,
        updatedAt: committedAt, updatedByUid: actorUid, updatedByName: actor.name,
        version: 1,
      }, warningId);
      assertCreatedCaseIsAdjudicable({
        warningId, warning: createdWarning,
        abnormalityId: request.abnormalityId, abnormality: after,
      });
      const creationAudit: UserAuthorityJsonMap = {
        schemaVersion: 1, eventType: "chargeAbnormalityMutation",
        entityType: "charge_abnormality", entityId: request.abnormalityId,
        action: "create", severity: "low", performedByUid: actorUid,
        performedByName: actor.name, timestamp: committedAt,
        reason: "other", reasonNotes: request.reason,
        summary: "Created charge abnormality and quality warning",
        beforeJson: null, afterJson: JSON.stringify(after), operation: request.operation,
        requestId: request.requestId, expectedVersion: 0, resultVersion: 1,
      };
      transaction.set(abnormalityRef, after);
      transaction.set(warningRef, createdWarning);
      transaction.set(auditRef, {...creationAudit});
      transaction.set(receiptRef, {
        schemaVersion: 1, requestId: request.requestId, actorUid,
        abnormalityId: request.abnormalityId, operation: request.operation,
        expectedVersion: 0, resultVersion: 1, auditId,
        payloadFingerprint: request.payloadFingerprint, committedAt, committedAtIso,
        linkedWarningId: warningId, linkedWarningVersion: 1,
        // Binds the accepted evidence, so a later retry detects any change to it.
        acceptedEvidenceVersion: 2,
        acceptedAuditSha256: acceptedAuditDigest(creationAudit),
      });
      return {ok: true, requestId: request.requestId,
        abnormalityId: request.abnormalityId, operation: request.operation,
        version: 1, auditId, committedAt: committedAtIso,
        idempotentReplay: false, abnormality: abnormalityForReceipt(after)};
    }

    if (!abnormalitySnapshot.exists) {
      throw new ChargeAbnormalityMutationError(
        receiptSnapshot.exists ? "data-loss" : "not-found",
        receiptSnapshot.exists ?
          "The recorded abnormality mutation target is missing." :
          "The charge abnormality was not found.",
        {
          reasonCode: receiptSnapshot.exists ?
            "abnormality-replay-target-missing" :
            "abnormality-not-found",
        },
      );
    }
    const existingData = abnormalitySnapshot.data() ?? {};
    // A reviewed repair is the one command that may read evidence recorded
    // twice, because collapsing those repeats is what it is for.
    const reviewed = request.operation === "RECONCILE_QUALITY_CASE" ?
      collapseRepeatedHierarchyReferences(existingData) :
      {record: existingData, repaired: false};
    const existing = validateExistingAbnormality(
      reviewed.record,
      request.abnormalityId,
      true,
    );
    const linkedTicketId = typeof existing.linkedTicketFirestoreId === "string" ?
      existing.linkedTicketFirestoreId.trim() : null;
    const warningId = linkedTicketId == null ?
      `abnormality_${request.abnormalityId}` : `issue_${linkedTicketId}`;
    if (linkedTicketId != null) {
      const ticketSnapshot = await transaction.get(
        db.collection("maintenance_records").doc(linkedTicketId),
      );
      const ticket = ticketSnapshot.exists ? ticketSnapshot.data() ?? {} : {};
      if (!ticketSnapshot.exists ||
          ticket.qualityAbnormalityId !== request.abnormalityId ||
          ticket.qualityWarningId !== warningId ||
          ticket.chargeQualityCaseId !== warningId ||
          ticket.chargeNoAtEvent !== existing.sourceChargeNo) {
        throw new ChargeAbnormalityMutationError(
          "data-loss",
          "The linked charge-quality case is incomplete.",
          {reasonCode: "charge-quality-case-link-invalid"},
        );
      }
    }
    const warningRef = db.collection("quality_warnings").doc(warningId);
    const warningSnapshot = await transaction.get(warningRef);
    const warning = warningSnapshot.exists ? validateQualityWarningRecord(
      warningSnapshot.data() ?? {},
      warningId,
    ) : null;
    const reconciling = request.operation === "RECONCILE_QUALITY_CASE";
    if (warning != null &&
        (warning.sourceChargeNo !== existing.sourceChargeNo ||
          (linkedTicketId == null ?
            (warning.sourceType !== "abnormality" ||
              warning.sourceId !== request.abnormalityId ||
              // A projection ahead of its source is drift a repair derives
              // away; the identities above are not derivable and still refuse.
              (!reconciling &&
                (warning.sourceVersion as number) >
                  (existing.version as number))) :
            (warning.sourceType !== "issue" ||
              warning.sourceId !== linkedTicketId)))) {
      throw new ChargeAbnormalityMutationError(
        "data-loss",
        "The charge abnormality and quality warning do not describe one case.",
        {reasonCode: "charge-quality-warning-link-invalid"},
      );
    }
    if (receiptSnapshot.exists) {
      return replayResult({
        request,
        actorUid,
        receipt: receiptSnapshot.data() ?? {},
        abnormality: existingData,
        audit: auditSnapshot.exists ? auditSnapshot.data() ?? {} : null,
        warning,
        warningId,
        auditId,
      });
    }
    if (auditSnapshot.exists) {
      throw new ChargeAbnormalityMutationError(
        "aborted",
        "The immutable abnormality audit identity is already occupied.",
        {reasonCode: "abnormality-audit-collision", auditId},
      );
    }

    if (warning == null) {
      throw new ChargeAbnormalityMutationError(
        "data-loss",
        "The charge abnormality is missing its quality warning.",
        {reasonCode: "charge-quality-warning-missing", warningId},
      );
    }
    if (existing.isDeleted === true) {
      throw new ChargeAbnormalityMutationError(
        "failed-precondition",
        "Deleted charge abnormalities cannot be mutated.",
        {reasonCode: "abnormality-already-deleted"},
      );
    }
    if (existing.version !== request.expectedVersion) {
      throw new ChargeAbnormalityMutationError(
        "aborted",
        "The charge abnormality changed before this command was committed.",
        {
          reasonCode: "abnormality-preimage-mismatch",
          currentVersion: existing.version,
        },
      );
    }

    if (request.operation === "RECONCILE_QUALITY_CASE") {
      return reconcileQualityCase({
        stored: existingData,
        existing,
        referencesRepaired: reviewed.repaired,
        warning,
        warningId,
        linkedTicketId,
        request,
        actorUid,
        actorName: actor.name,
        auditId,
        now,
        timestampFromDate,
        commit: (records) => {
          transaction.set(abnormalityRef, records.abnormality);
          transaction.set(warningRef, records.warning);
          transaction.set(auditRef, records.audit);
          transaction.set(receiptRef, records.receipt);
        },
      });
    }

    let type:
      | {readonly code: string; readonly title: string; readonly category: string}
      | null = null;
    if (request.update != null) {
      if (
        request.update.reannealedToChargeNo != null &&
        request.update.reannealedToChargeNo === existing.sourceChargeNo
      ) {
        throw new ChargeAbnormalityMutationError(
          "failed-precondition",
          "The re-annealed charge must differ from the source charge.",
          {reasonCode: "reannealed-charge-matches-source"},
        );
      }
      if (request.update.abnormalityTypeId === existing.abnormalityTypeId) {
        // Historical records retain the governed classification frozen when
        // they were logged. Retiring that master later must not block an
        // otherwise valid Admin correction that keeps the same type.
        type = {
          code: existing.abnormalityTypeCode as string,
          title: existing.abnormalityTypeTitle as string,
          category: existing.category as string,
        };
      } else {
        const typeRef = db
          .collection("abnormality_types")
          .doc(request.update.abnormalityTypeId);
        type = canonicalType(
          await transaction.get(typeRef),
          request.update.abnormalityTypeId,
        );
      }
    }

    const committedAtDate = now();
    const committedAtIso = committedAtDate.toISOString();
    const committedAt = timestampFromDate(committedAtDate);
    if (committedAtDate.valueOf() < persistedInstantMillis(existing.updatedAt)) {
      throw new ChargeAbnormalityMutationError(
        "aborted",
        "The server clock precedes the current abnormality update. Retry after the recorded time boundary.",
        {reasonCode: "charge-abnormality-clock-regression"},
      );
    }
    const resultVersion = request.expectedVersion + 1;
    if (!Number.isSafeInteger(resultVersion)) {
      throw new ChargeAbnormalityMutationError(
        "failed-precondition",
        "The charge-abnormality version cannot advance safely.",
        {reasonCode: "abnormality-version-overflow"},
      );
    }

    const after: UserAuthorityJsonMap = {...existing};
    Object.assign(after, canonicalNullableGaps(existing));
    if (request.update != null && type != null) {
      const existingAffectedAssets = existingAssets(existing.affectedAssets);
      const existingHierarchyRefs = parseAffectedAssetHierarchyRefs(
        existing.affectedAssetHierarchyRefs,
        existingAffectedAssets,
      ) ?? [];
      const requestedHierarchyRefs =
        request.update.affectedAssetHierarchyRefs;
      const affectedAssetHierarchyRefs = mergeAffectedAssetHierarchyRefs({
        affectedAssets: request.update.affectedAssets,
        existing: existingHierarchyRefs,
        requested: requestedHierarchyRefs,
      });
      Object.assign(after, {
        abnormalityTypeId: request.update.abnormalityTypeId,
        abnormalityTypeTitle: type.title,
        abnormalityTypeCode: type.code,
        category: type.category,
        severity: request.update.severity,
        affectedAssets: request.update.affectedAssets,
        affectedAssetHierarchyRefs,
        component: request.update.component,
        observedReason: request.update.observedReason,
        description: request.update.description,
        possibleRootReasonCategory:
          request.update.possibleRootReasonCategory,
        possibleRootReasonNotes: request.update.possibleRootReasonNotes,
        reannealingStatus: request.update.reannealingStatus,
        reannealedToChargeNo: request.update.reannealedToChargeNo,
      });
    } else {
      Object.assign(after, {
        isDeleted: true,
        deletedAt: committedAtIso,
        deletedByUid: actorUid,
        deletedByName: actor.name,
        deleteReason: request.reason,
      });
    }
    Object.assign(after, {
      updatedAt: committedAtIso,
      updatedByUid: actorUid,
      updatedByName: actor.name,
      version: resultVersion,
    });
    validateExistingAbnormality(after, request.abnormalityId);

    if (request.operation === "SOFT_DELETE") {
      if (linkedTicketId != null) {
        throw new ChargeAbnormalityMutationError(
          "failed-precondition",
          "A linked issue abnormality cannot be deleted independently.",
          {reasonCode: "linked-charge-abnormality-delete-denied"},
        );
      }
      if (warning.status !== "closed") {
        throw new ChargeAbnormalityMutationError(
          "failed-precondition",
          "Close the related quality warning before deleting this abnormality.",
          {reasonCode: "charge-quality-warning-open"},
        );
      }
    }
    if (request.operation === "UPDATE" && warning.status === "closed") {
      const materialField = materialCaseChange(existing, after);
      if (materialField != null) {
        throw new ChargeAbnormalityMutationError(
          "failed-precondition",
          "Reopen the closed quality decision before correcting this evidence. " +
          "The description and root-cause notes stay editable while it is closed.",
          {
            reasonCode: "charge-quality-decision-reopen-required",
            field: materialField,
          },
        );
      }
    }
    const warningAfter = request.operation === "UPDATE" ?
      warningAfterAbnormalityUpdate({
        beforeAbnormality: existing,
        afterAbnormality: after,
        warning,
        warningId,
        linkedTicketId,
        actorUid,
        actorName: actor.name,
        requestId: request.requestId,
        reason: request.reason,
        committedAt,
      }) : null;

    const auditAction =
      request.operation === "UPDATE" ? "update" : "delete";
    transaction.set(abnormalityRef, after);
    if (warningAfter != null) transaction.set(warningRef, warningAfter);
    const mutationAudit: UserAuthorityJsonMap = {
      schemaVersion: 1,
      eventType: "chargeAbnormalityMutation",
      entityType: "charge_abnormality",
      entityId: request.abnormalityId,
      action: auditAction,
      severity: "high",
      performedByUid: actorUid,
      performedByName: actor.name,
      timestamp: committedAt,
      reason: "manualOverride",
      reasonNotes: request.reason,
      summary:
        request.operation === "UPDATE" ?
          "Updated charge abnormality" :
          "Soft-deleted charge abnormality",
      beforeJson: JSON.stringify(existing),
      afterJson: JSON.stringify(after),
      requestId: request.requestId,
      operation: request.operation,
      expectedVersion: request.expectedVersion,
      resultVersion,
      linkedWarningId: warningId,
      linkedWarningBeforeVersion: warning.version,
      linkedWarningResultVersion: warningAfter?.version ?? warning.version,
    };
    transaction.set(auditRef, {...mutationAudit});
    transaction.set(receiptRef, {
      schemaVersion: 1,
      requestId: request.requestId,
      actorUid,
      abnormalityId: request.abnormalityId,
      operation: request.operation,
      payloadFingerprint: request.payloadFingerprint,
      expectedVersion: request.expectedVersion,
      resultVersion,
      linkedWarningId: warningId,
      linkedWarningVersion: warningAfter?.version ?? warning.version,
      auditId,
      committedAt,
      committedAtIso,
      // Binds the accepted evidence, so a later retry detects any change to it.
      acceptedEvidenceVersion: 2,
      acceptedAuditSha256: acceptedAuditDigest(mutationAudit),
    });

    return {
      ok: true,
      requestId: request.requestId,
      abnormalityId: request.abnormalityId,
      operation: request.operation,
      version: resultVersion,
      auditId,
      committedAt: committedAtIso,
      idempotentReplay: false,
      abnormality: abnormalityForReceipt(after),
    };
  });
}
