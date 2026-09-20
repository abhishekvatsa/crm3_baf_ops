import {createHash} from "crypto";
import {isFiveDigitChargeNumber} from "./chargeNumber";
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

export type QualityMutationOperation =
  | "REQUEST_QUALITY_WARNING_CLOSURE"
  | "DECLARE_QUALITY_CASE_RA_REQUIRED"
  | "RECORD_QUALITY_CASE_RA_COMPLETED"
  | "CLOSE_QUALITY_WARNING"
  | "REOPEN_QUALITY_WARNING"
  | "CREATE_QUALITY_MONITORING_REQUEST"
  | "CLOSE_QUALITY_MONITORING_REQUEST"
  | "CORRECT_QUALITY_MONITORING_REQUEST"
  | "CANCEL_QUALITY_MONITORING_REQUEST";

export function qualityAuditActionForOperation(
  operation: QualityMutationOperation,
): "create" | "update" | "resolve" | "reopen" {
  switch (operation) {
  case "REQUEST_QUALITY_WARNING_CLOSURE":
  case "DECLARE_QUALITY_CASE_RA_REQUIRED":
  case "RECORD_QUALITY_CASE_RA_COMPLETED":
  case "CORRECT_QUALITY_MONITORING_REQUEST":
    return "update";
  case "CLOSE_QUALITY_WARNING":
  case "CLOSE_QUALITY_MONITORING_REQUEST":
  case "CANCEL_QUALITY_MONITORING_REQUEST":
    return "resolve";
  case "REOPEN_QUALITY_WARNING":
    return "reopen";
  case "CREATE_QUALITY_MONITORING_REQUEST":
    return "create";
  }
}

export type QualityMutationErrorCode =
  | "invalid-argument"
  | "unauthenticated"
  | "permission-denied"
  | "not-found"
  | "already-exists"
  | "failed-precondition"
  | "aborted"
  | "data-loss"
  | "internal";

type SnapshotLike = {
  exists: boolean;
  id?: string;
  data: () => UserAuthorityJsonMap | undefined;
};

type QuerySnapshotLike = {
  docs: SnapshotLike[];
};

type QueryLike = {
  limit: (count: number) => QueryLike;
  get: () => Promise<QuerySnapshotLike>;
};

type DocumentRefLike = {
  id?: string;
  path?: string;
  get: () => Promise<SnapshotLike>;
};

type TransactionLike = {
  get: (ref: DocumentRefLike) => Promise<SnapshotLike>;
  set: (
    ref: DocumentRefLike,
    data: UserAuthorityJsonMap,
    options?: UserAuthorityJsonMap,
  ) => void;
};

export type QualityMutationFirestoreLike = {
  collection: (name: string) => {
    doc: (id: string) => DocumentRefLike;
    where?: (field: string, operator: "==", value: unknown) => QueryLike;
  };
  runTransaction: <T>(fn: (transaction: TransactionLike) => Promise<T>) =>
    Promise<T>;
};

type WarningOperation = Exclude<
  QualityMutationOperation,
  "CREATE_QUALITY_MONITORING_REQUEST" |
  "CLOSE_QUALITY_MONITORING_REQUEST" |
  "CORRECT_QUALITY_MONITORING_REQUEST" | "CANCEL_QUALITY_MONITORING_REQUEST"
>;

type ParsedWarningRequest = {
  requestId: string;
  operation: WarningOperation;
  warningId: string;
  expectedVersion: number;
  reason: string;
  disposition: string | null;
  linkedReannealingChargeNos: ReadonlyArray<number>;
  fingerprint: string;
};

type ParsedMonitoringRequest = {
  requestId: string;
  operation:
    | "CREATE_QUALITY_MONITORING_REQUEST"
    | "CLOSE_QUALITY_MONITORING_REQUEST"
  | "CORRECT_QUALITY_MONITORING_REQUEST"
  | "CANCEL_QUALITY_MONITORING_REQUEST";
  monitoringRequestId: string;
  expectedVersion: number;
  reason: string;
  baseNumber: number | null;
  baseAssetClassId: string | null;
  baseAssetInstanceId: string | null;
  baseAssetInstanceVersion: number | null;
  grade: string | null;
  cycleReference: string | null;
  chargeNumbers: ReadonlyArray<number>;
  fingerprint: string;
};

type ParsedRequest = ParsedWarningRequest | ParsedMonitoringRequest;

export interface QualityMutationResult {
  ok: true;
  requestId: string;
  operation: QualityMutationOperation;
  entityId: string;
  version: number;
  auditId: string;
  committedAt: string;
  idempotentReplay: boolean;
  entity: UserAuthorityJsonMap;
  linkedAbnormality: UserAuthorityJsonMap | null;
}

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const OPERATIONS = new Set<QualityMutationOperation>([
  "REQUEST_QUALITY_WARNING_CLOSURE",
  "DECLARE_QUALITY_CASE_RA_REQUIRED",
  "RECORD_QUALITY_CASE_RA_COMPLETED",
  "CLOSE_QUALITY_WARNING",
  "REOPEN_QUALITY_WARNING",
  "CREATE_QUALITY_MONITORING_REQUEST",
  "CLOSE_QUALITY_MONITORING_REQUEST",
  "CORRECT_QUALITY_MONITORING_REQUEST",
  "CANCEL_QUALITY_MONITORING_REQUEST",
]);
export const QUALITY_MONITORING_OPERATIONAL_RETENTION_MS =
  7 * 24 * 60 * 60 * 1000;
const REQUEST_ROLES = new Set([
  "admin",
  "si",
  "shiftSupervisor",
  "operations",
]);
const RA_LIFECYCLE_ROLES = new Set([
  "admin",
  "si",
  "shiftSupervisor",
  "operations",
]);
const DECISION_ROLES = new Set(["admin", "si"]);
const DISPOSITIONS = new Set([
  "coilFoundAcceptable",
  "reannealingCompleted",
  "qualityAdjudication",
]);
const WARNING_STATUSES = new Set(["open", "closureRequested", "closed"]);

// Governed records now carry every optional key with an explicit null. Records
// written before that omitted them, where absence means "no value". It never
// stands in for a missing actor, charge, time or re-annealing result, so those
// fields stay required.
const LEGACY_NULLABLE_WARNING_FIELDS = new Set([
  "component",
  "closureRequestReason",
  "closureRequestedAt",
  "closureRequestedByUid",
  "closureRequestedByName",
  "closedAt",
  "closedByUid",
  "closedByName",
  "closureDisposition",
  "decisionReason",
  "createdByName",
  "updatedByName",
]);

const LEGACY_NULLABLE_CASE_FIELDS = new Set([
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
  fields: ReadonlySet<string>,
): UserAuthorityJsonMap {
  const gaps: UserAuthorityJsonMap = {};
  for (const field of fields) {
    if (!Object.prototype.hasOwnProperty.call(record, field)) {
      gaps[field] = null;
    }
  }
  return gaps;
}
/**
 * The canonical null keys a stored warning is missing, so a reviewed repair can
 * store today's representation without inventing evidence.
 */
export function canonicalQualityWarningGaps(
  record: UserAuthorityJsonMap,
): UserAuthorityJsonMap {
  return canonicalNullableGaps(record, LEGACY_NULLABLE_WARNING_FIELDS);
}

const REANNEALING_STATUSES = new Set([
  "notApplicable",
  "pendingDecision",
  "required",
  "notRequired",
  "completed",
]);
const LINKED_ABNORMALITY_FIELDS = new Set([
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
const WARNING_FIELDS = new Set([
  "schemaVersion",
  "warningId",
  "sourceType",
  "sourceId",
  "sourceVersion",
  "sourceChargeNo",
  "sourceSummary",
  "sourceSeverity",
  "warningReason",
  "affectedAssets",
  "component",
  "status",
  "closureRequestReason",
  "closureRequestedAt",
  "closureRequestedByUid",
  "closureRequestedByName",
  "closedAt",
  "closedByUid",
  "closedByName",
  "closureDisposition",
  "linkedReannealingChargeNos",
  "decisionReason",
  "createdAt",
  "createdByUid",
  "createdByName",
  "updatedAt",
  "updatedByUid",
  "updatedByName",
  "version",
  "lastMutationId",
  "_globalPullServerUpdatedAt",
]);
const MONITORING_REVIEW_FIELDS = new Set(["monitoringDisposition", "originalMonitoringContext"]);
const MONITORING_CONTEXT_FIELDS = ["baseNumber", "baseAssetClassId", "baseAssetInstanceId",
  "baseAssetInstanceVersion", "grade", "cycleReference", "chargeNumbers", "reason"];
const monitoringContext = (row: UserAuthorityJsonMap): UserAuthorityJsonMap =>
  Object.fromEntries(MONITORING_CONTEXT_FIELDS.map((key) => [key, row[key] ?? null]));

const MONITORING_FIELDS = new Set([
  "schemaVersion",
  "requestId",
  "baseNumber",
  "baseAssetClassId",
  "baseAssetInstanceId",
  "baseAssetInstanceVersion",
  "grade",
  "cycleReference",
  "chargeNumbers",
  "reason",
  "status",
  "visibilityState",
  "visibleUntil",
  "archivedAt",
  "createdAt",
  "createdByUid",
  "createdByName",
  "closedAt",
  "closedByUid",
  "closedByName",
  "closeReason",
  "updatedAt",
  "updatedByUid",
  "updatedByName",
  "version",
  "lastMutationId",
  "_globalPullServerUpdatedAt",
]);
const MONITORING_VISIBILITY_FIELDS = new Set([
  "visibilityState",
  "visibleUntil",
  "archivedAt",
]);
const MONITORING_BASE_IDENTITY_FIELDS = new Set([
  "baseAssetClassId",
  "baseAssetInstanceId",
  "baseAssetInstanceVersion",
]);
const ABNORMALITY_CATEGORIES = new Set([
  "process",
  "equipment",
  "resultQuality",
  "reannealing",
  "other",
]);
const ABNORMALITY_SEVERITIES = new Set([
  "low",
  "medium",
  "high",
  "critical",
]);
const ABNORMALITY_ROOT_REASON_CATEGORIES = new Set([
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
const ABNORMALITY_ASSET_TYPES = new Set([
  "base",
  "furnace",
  "forceCooler",
  "innerCover",
  "governedCustom",
]);

export class QualityMutationError extends Error {
  readonly code: QualityMutationErrorCode;
  readonly details?: unknown;

  constructor(
    code: QualityMutationErrorCode,
    message: string,
    details?: unknown,
  ) {
    super(message);
    this.name = "QualityMutationError";
    this.code = code;
    this.details = details;
  }
}

function invalid(field: string, detail: string): never {
  throw new QualityMutationError(
    "invalid-argument",
    `${field} ${detail}.`,
    {reasonCode: "invalid-quality-mutation-request", field},
  );
}

function requiredString(value: unknown, field: string, max: number): string {
  if (typeof value !== "string") invalid(field, "must be a string");
  const cleaned = (value as string).trim();
  if (cleaned.length === 0 || cleaned.length > max) {
    invalid(field, `must contain 1-${max} characters`);
  }
  return cleaned;
}

function documentId(value: unknown, field: string): string {
  const id = requiredString(value, field, 512);
  if (id === "." || id === ".." || id.includes("/")) {
    invalid(field, "is not a valid document identity");
  }
  return id;
}

function nonNegativeInteger(value: unknown, field: string): number {
  if (!Number.isSafeInteger(value) || (value as number) < 0) {
    invalid(field, "must be a non-negative safe integer");
  }
  return value as number;
}

function positiveInteger(value: unknown, field: string): number {
  const number = nonNegativeInteger(value, field);
  if (number === 0) invalid(field, "must be positive");
  return number;
}

function positiveIntegerList(
  value: unknown,
  field: string,
  maximum: number,
): ReadonlyArray<number> {
  if (value == null) return [];
  if (!Array.isArray(value) || value.length > maximum) {
    invalid(field, `must be a list of at most ${maximum} integers`);
  }
  const result = value.map((item, index) =>
    positiveInteger(item, `${field}[${index}]`));
  if (result.some((item) => !isFiveDigitChargeNumber(item))) {
    invalid(field, "must contain only five-digit charge numbers");
  }
  if (new Set(result).size !== result.length) {
    invalid(field, "must not contain duplicates");
  }
  return [...result].sort((left, right) => left - right);
}

function requestFingerprint(value: unknown): string {
  return `qualityreq1-sha256:${createHash("sha256")
    .update(stableJson(value), "utf8").digest("hex")}`;
}

export function isQualityMutationOperation(
  value: unknown,
): value is QualityMutationOperation {
  return typeof value === "string" &&
    OPERATIONS.has(value as QualityMutationOperation);
}

export function userCanMutateQuality(
  data: UserAuthorityJsonMap,
  operation: QualityMutationOperation,
): boolean {
  const authority = canonicalApprovedUserAuthority(data);
  if (authority == null) return false;
  const roles = operation === "REQUEST_QUALITY_WARNING_CLOSURE" ?
    REQUEST_ROLES :
    operation === "DECLARE_QUALITY_CASE_RA_REQUIRED" ||
    operation === "RECORD_QUALITY_CASE_RA_COMPLETED" ?
      RA_LIFECYCLE_ROLES : DECISION_ROLES;
  return [...authority.roles].some((role) => roles.has(role));
}

export function parseQualityMutationRequest(
  raw: UserAuthorityJsonMap,
): ParsedRequest {
  const operation = requiredString(
    raw.operation,
    "operation",
    64,
  ) as QualityMutationOperation;
  if (!OPERATIONS.has(operation)) invalid("operation", "is unsupported");
  const requestId = requiredString(raw.requestId, "requestId", 64);
  if (!UUID.test(requestId)) invalid("requestId", "must be a canonical UUID");
  const reason = requiredString(raw.reason, "reason", 2000);
  const expectedVersion = nonNegativeInteger(
    raw.expectedVersion,
    "expectedVersion",
  );

  if (operation.includes("MONITORING_REQUEST")) {
    const monitoringOperation = operation as ParsedMonitoringRequest["operation"];
    const create = operation === "CREATE_QUALITY_MONITORING_REQUEST";
    const contextChange = create || operation === "CORRECT_QUALITY_MONITORING_REQUEST";
    const allowed = new Set([
      "requestId",
      "operation",
      "monitoringRequestId",
      "expectedVersion",
      "reason",
      ...(contextChange ? [
        "baseNumber",
        "baseAssetClassId",
        "baseAssetInstanceId",
        "baseAssetInstanceVersion",
        "grade",
        "cycleReference",
        "chargeNumbers",
      ] : []),
    ]);
    for (const key of Object.keys(raw)) if (!allowed.has(key)) invalid(key, "is unsupported");
    const monitoringRequestId = documentId(
      raw.monitoringRequestId,
      "monitoringRequestId",
    );
    if (!UUID.test(monitoringRequestId)) {
      invalid("monitoringRequestId", "must be a canonical UUID");
    }
    if (create && expectedVersion !== 0) {
      invalid("expectedVersion", "must be zero when creating monitoring");
    }
    if (!create && expectedVersion === 0) {
      invalid("expectedVersion", "must identify the current monitoring version");
    }
    const identityKeys = [
      "baseAssetClassId",
      "baseAssetInstanceId",
      "baseAssetInstanceVersion",
    ];
    const identityFieldCount = contextChange ? identityKeys.filter((key) =>
      Object.prototype.hasOwnProperty.call(raw, key)).length : 0;
    if (identityFieldCount !== 0 && identityFieldCount !== identityKeys.length) {
      invalid(
        "baseAssetInstanceId",
        "requires the complete governed Base identity",
      );
    }
    if (!create && contextChange && identityFieldCount !== identityKeys.length) {
      invalid("baseAssetInstanceId", "requires a reviewed exact Base for correction");
    }
    const baseAssetClassId = identityFieldCount === identityKeys.length ?
      documentId(raw.baseAssetClassId, "baseAssetClassId") : null;
    const baseAssetInstanceId = identityFieldCount === identityKeys.length ?
      documentId(raw.baseAssetInstanceId, "baseAssetInstanceId") : null;
    const baseAssetInstanceVersion = identityFieldCount === identityKeys.length ?
      positiveInteger(
        raw.baseAssetInstanceVersion,
        "baseAssetInstanceVersion",
      ) : null;
    const legacyCanonical = {
      requestId,
      operation: monitoringOperation,
      monitoringRequestId,
      expectedVersion,
      reason,
      baseNumber: contextChange ? positiveInteger(raw.baseNumber, "baseNumber") : null,
      grade: contextChange ? requiredString(raw.grade, "grade", 120) : null,
      cycleReference: contextChange ?
        requiredString(raw.cycleReference, "cycleReference", 200) : null,
      chargeNumbers: contextChange ?
        positiveIntegerList(raw.chargeNumbers, "chargeNumbers", 50) : [],
    };
    const fingerprintPayload = baseAssetClassId == null ?
      legacyCanonical : {
        ...legacyCanonical,
        baseAssetClassId,
        baseAssetInstanceId,
        baseAssetInstanceVersion,
      };
    return {
      ...legacyCanonical,
      baseAssetClassId,
      baseAssetInstanceId,
      baseAssetInstanceVersion,
      fingerprint: requestFingerprint(fingerprintPayload),
    };
  }

  const close = operation === "CLOSE_QUALITY_WARNING";
  const recordRaCompletion =
    operation === "RECORD_QUALITY_CASE_RA_COMPLETED";
  const allowed = new Set([
    "requestId",
    "operation",
    "warningId",
    "expectedVersion",
    "reason",
    ...(close ? ["disposition", "linkedReannealingChargeNos"] : []),
    ...(recordRaCompletion ? ["linkedReannealingChargeNos"] : []),
  ]);
  for (const key of Object.keys(raw)) if (!allowed.has(key)) invalid(key, "is unsupported");
  const disposition = close ? requiredString(raw.disposition, "disposition", 64) : null;
  if (disposition != null && !DISPOSITIONS.has(disposition)) {
    invalid("disposition", "is unsupported");
  }
  const linkedReannealingChargeNos = close || recordRaCompletion ?
    positiveIntegerList(
      raw.linkedReannealingChargeNos,
      "linkedReannealingChargeNos",
      recordRaCompletion ? 1 : 20,
    ) : [];
  if (recordRaCompletion && linkedReannealingChargeNos.length !== 1) {
    invalid(
      "linkedReannealingChargeNos",
      "must contain exactly one resulting charge for operational RA completion",
    );
  }
  if (disposition === "reannealingCompleted" &&
      linkedReannealingChargeNos.length === 0) {
    invalid(
      "linkedReannealingChargeNos",
      "must contain at least one RA charge for re-annealing closure",
    );
  }
  if (!recordRaCompletion &&
      disposition !== "reannealingCompleted" &&
      linkedReannealingChargeNos.length > 0) {
    invalid(
      "linkedReannealingChargeNos",
      "is allowed only for re-annealing closure",
    );
  }
  const canonical = {
    requestId,
    operation: operation as WarningOperation,
    warningId: documentId(raw.warningId, "warningId"),
    expectedVersion,
    reason,
    disposition,
    linkedReannealingChargeNos,
  };
  return {...canonical, fingerprint: requestFingerprint(canonical)};
}

function actorFromSnapshot(
  snapshot: SnapshotLike,
  actorUid: string,
  operation: QualityMutationOperation,
): {name: string} {
  const data = snapshot.exists ? snapshot.data() ?? {} : {};
  if (!userCanMutateQuality(data, operation)) {
    throw new QualityMutationError(
      "permission-denied",
      "The current account cannot perform this quality decision.",
      {reasonCode: "quality-authority-required", operation},
    );
  }
  const name = typeof data.name === "string" && data.name.trim().length > 0 ?
    data.name.trim() : actorUid;
  return {name};
}

function validDate(value: unknown): boolean {
  return isValidPersistedInstant(value);
}

function dateMillis(value: unknown, field: string, entity: string): number {
  const millis = persistedInstantMillis(value);
  return Number.isFinite(millis) ? millis : malformed(entity, field);
}

function malformed(entity: string, field?: string): never {
  throw new QualityMutationError(
    "failed-precondition",
    `The persisted ${entity} is malformed.`,
    {reasonCode: `${entity}-malformed`, ...(field == null ? {} : {field})},
  );
}

function requireMonotonicQualityCommit(
  committedDate: Date,
  data: UserAuthorityJsonMap,
  entity: string,
): void {
  if (committedDate.valueOf() < dateMillis(data.updatedAt, "updatedAt", entity)) {
    throw new QualityMutationError(
      "aborted",
      "The server clock precedes the current quality record. Retry after the recorded time boundary.",
      {reasonCode: `${entity}-clock-regression`},
    );
  }
}

export function validateQualityWarningRecord(
  data: UserAuthorityJsonMap,
  warningId: string,
): UserAuthorityJsonMap {
  for (const key of Object.keys(data)) {
    if (!WARNING_FIELDS.has(key)) malformed("quality-warning", key);
  }
  for (const field of [...WARNING_FIELDS].filter((value) =>
    value !== "_globalPullServerUpdatedAt" && value !== "lastMutationId" &&
      !LEGACY_NULLABLE_WARNING_FIELDS.has(value))) {
    if (!Object.prototype.hasOwnProperty.call(data, field)) {
      malformed("quality-warning", field);
    }
  }
  if (data.schemaVersion !== 1 || data.warningId !== warningId) {
    malformed("quality-warning", "warningId");
  }
  if (data.sourceType !== "issue" && data.sourceType !== "abnormality") {
    malformed("quality-warning", "sourceType");
  }
  const sourceId = requiredExistingString(
    data.sourceId,
    "sourceId",
    "quality-warning",
  );
  if (warningId !== `${data.sourceType}_${sourceId}`) {
    malformed("quality-warning", "sourceId");
  }
  positiveExistingInteger(data.sourceVersion, "sourceVersion", "quality-warning");
  positiveExistingInteger(data.sourceChargeNo, "sourceChargeNo", "quality-warning");
  if (!isFiveDigitChargeNumber(data.sourceChargeNo)) {
    malformed("quality-warning", "sourceChargeNo");
  }
  requiredExistingString(data.sourceSummary, "sourceSummary", "quality-warning");
  requiredExistingString(data.sourceSeverity, "sourceSeverity", "quality-warning");
  requiredExistingString(data.warningReason, "warningReason", "quality-warning");
  if (!Array.isArray(data.affectedAssets) ||
      data.affectedAssets.length > 50) {
    malformed("quality-warning", "affectedAssets");
  }
  const affectedAssetIdentities = new Set<string>();
  data.affectedAssets.forEach((raw, index) => {
    if (raw == null || typeof raw !== "object" || Array.isArray(raw)) {
      malformed("quality-warning", `affectedAssets[${index}]`);
    }
    const asset = raw as UserAuthorityJsonMap;
    const keys = Object.keys(asset);
    const hasHierarchyReference = Object.prototype.hasOwnProperty.call(
      asset,
      "assetHierarchyRef",
    );
    if ((keys.length !== 2 &&
         !(keys.length === 3 && hasHierarchyReference)) ||
        !Object.prototype.hasOwnProperty.call(asset, "assetType") ||
        !Object.prototype.hasOwnProperty.call(asset, "assetNumber")) {
      malformed("quality-warning", `affectedAssets[${index}]`);
    }
    const assetType = requiredExistingString(
      asset.assetType,
      `affectedAssets[${index}].assetType`,
      "quality-warning",
    );
    if (!ABNORMALITY_ASSET_TYPES.has(assetType)) {
      malformed("quality-warning", `affectedAssets[${index}].assetType`);
    }
    const assetNumber = positiveExistingInteger(
      asset.assetNumber,
      `affectedAssets[${index}].assetNumber`,
      "quality-warning",
    );
    // Set.prototype.add returns the set itself, so test membership first.
    const identity = `${assetType}:${assetNumber}`;
    if (affectedAssetIdentities.has(identity)) {
      malformed("quality-warning", "affectedAssets");
    }
    affectedAssetIdentities.add(identity);
    if (hasHierarchyReference &&
        !isValidAffectedAssetHierarchyReference(
          asset.assetHierarchyRef,
          assetNumber,
        )) {
      malformed(
        "quality-warning",
        `affectedAssets[${index}].assetHierarchyRef`,
      );
    }
  });
  optionalExistingString(data.component, "component", "quality-warning");
  if (typeof data.status !== "string" || !WARNING_STATUSES.has(data.status)) {
    malformed("quality-warning", "status");
  }
  if (!Array.isArray(data.linkedReannealingChargeNos) ||
      data.linkedReannealingChargeNos.length > 20) {
    malformed("quality-warning", "linkedReannealingChargeNos");
  }
  const charges = data.linkedReannealingChargeNos.map((value, index) =>
    positiveExistingInteger(
      value,
      `linkedReannealingChargeNos[${index}]`,
      "quality-warning",
    ));
  if (charges.some((chargeNo) => !isFiveDigitChargeNumber(chargeNo)) ||
      new Set(charges).size !== charges.length) {
    malformed("quality-warning", "linkedReannealingChargeNos");
  }
  positiveExistingInteger(data.version, "version", "quality-warning");
  requiredExistingString(data.createdByUid, "createdByUid", "quality-warning");
  optionalExistingString(data.createdByName, "createdByName", "quality-warning");
  requiredExistingString(data.updatedByUid, "updatedByUid", "quality-warning");
  optionalExistingString(data.updatedByName, "updatedByName", "quality-warning");
  if (!validDate(data.createdAt) || !validDate(data.updatedAt)) {
    malformed("quality-warning", "updatedAt");
  }
  const createdAtMillis = dateMillis(
    data.createdAt,
    "createdAt",
    "quality-warning",
  );
  const updatedAtMillis = dateMillis(
    data.updatedAt,
    "updatedAt",
    "quality-warning",
  );
  if (updatedAtMillis < createdAtMillis) {
    malformed("quality-warning", "updatedAt");
  }
  if (data.lastMutationId != null &&
      (typeof data.lastMutationId !== "string" || !UUID.test(data.lastMutationId))) {
    malformed("quality-warning", "lastMutationId");
  }
  if (data._globalPullServerUpdatedAt != null &&
      !validDate(data._globalPullServerUpdatedAt)) {
    malformed("quality-warning", "_globalPullServerUpdatedAt");
  }

  const requestEvidence = [
    optionalExistingString(
      data.closureRequestReason,
      "closureRequestReason",
      "quality-warning",
    ),
    optionalExistingDate(
      data.closureRequestedAt,
      "closureRequestedAt",
      "quality-warning",
    ),
    optionalExistingString(
      data.closureRequestedByUid,
      "closureRequestedByUid",
      "quality-warning",
    ),
    optionalExistingString(
      data.closureRequestedByName,
      "closureRequestedByName",
      "quality-warning",
    ),
  ];
  const requestEvidenceCount = requestEvidence.filter((value) => value != null).length;
  if (requestEvidenceCount !== 0 && requestEvidenceCount !== requestEvidence.length) {
    malformed("quality-warning", "closureRequestReason");
  }
  const closureRequestedAt = requestEvidence[1];
  let closureRequestedAtMillis: number | null = null;
  if (closureRequestedAt != null) {
    closureRequestedAtMillis = dateMillis(
      closureRequestedAt,
      "closureRequestedAt",
      "quality-warning",
    );
    if (closureRequestedAtMillis < createdAtMillis ||
        closureRequestedAtMillis > updatedAtMillis) {
      malformed("quality-warning", "closureRequestedAt");
    }
  }
  const closedAt = optionalExistingDate(
    data.closedAt,
    "closedAt",
    "quality-warning",
  );
  const closedByUid = optionalExistingString(
    data.closedByUid,
    "closedByUid",
    "quality-warning",
  );
  const closedByName = optionalExistingString(
    data.closedByName,
    "closedByName",
    "quality-warning",
  );
  const decisionReason = optionalExistingString(
    data.decisionReason,
    "decisionReason",
    "quality-warning",
  );
  const disposition = data.closureDisposition;
  if (disposition != null &&
      (typeof disposition !== "string" || !DISPOSITIONS.has(disposition))) {
    malformed("quality-warning", "closureDisposition");
  }
  const hasClosedEvidence = closedAt != null || closedByUid != null ||
    closedByName != null || disposition != null || decisionReason != null;
  const completeClosedEvidence = closedAt != null && closedByUid != null &&
    closedByName != null && disposition != null && decisionReason != null;
  if (closedAt != null) {
    const closedAtMillis = dateMillis(
      closedAt,
      "closedAt",
      "quality-warning",
    );
    if (closedAtMillis < createdAtMillis ||
        closedAtMillis > updatedAtMillis ||
        (closureRequestedAtMillis != null &&
          closedAtMillis < closureRequestedAtMillis)) {
      malformed("quality-warning", "closedAt");
    }
  }
  if (data.status === "open" &&
      (requestEvidenceCount !== 0 || hasClosedEvidence || charges.length !== 0)) {
    malformed("quality-warning", "status");
  }
  if (data.status === "closureRequested" &&
      (requestEvidenceCount !== requestEvidence.length ||
        hasClosedEvidence || charges.length !== 0)) {
    malformed("quality-warning", "status");
  }
  if (data.status === "closed" && !completeClosedEvidence) {
    malformed("quality-warning", "status");
  }
  if (disposition === "reannealingCompleted") {
    if (charges.length === 0) {
      malformed("quality-warning", "linkedReannealingChargeNos");
    }
  } else if (charges.length !== 0) {
    malformed("quality-warning", "linkedReannealingChargeNos");
  }
  return {...data};
}

function linkedAffectedAssetEntry(
  raw: unknown,
  field: string,
  requireHierarchy: boolean,
): {identity: string; hasHierarchy: boolean} {
  if (raw == null || typeof raw !== "object" || Array.isArray(raw)) {
    malformed("charge-quality-abnormality", field);
  }
  const asset = raw as UserAuthorityJsonMap;
  const hasHierarchy = Object.prototype.hasOwnProperty.call(
    asset,
    "assetHierarchyRef",
  );
  const keys = Object.keys(asset);
  if ((keys.length !== 2 && !(keys.length === 3 && hasHierarchy)) ||
      !Object.prototype.hasOwnProperty.call(asset, "assetType") ||
      !Object.prototype.hasOwnProperty.call(asset, "assetNumber") ||
      (requireHierarchy && !hasHierarchy) ||
      typeof asset.assetType !== "string" ||
      !ABNORMALITY_ASSET_TYPES.has(asset.assetType)) {
    malformed("charge-quality-abnormality", field);
  }
  const assetNumber = positiveExistingInteger(
    asset.assetNumber,
    `${field}.assetNumber`,
    "charge-quality-abnormality",
  );
  if (hasHierarchy &&
      !isValidAffectedAssetHierarchyReference(
        asset.assetHierarchyRef,
        assetNumber,
      )) {
    malformed("charge-quality-abnormality", `${field}.assetHierarchyRef`);
  }
  return {identity: `${asset.assetType}:${assetNumber}`, hasHierarchy};
}

function validateLinkedAffectedAssets(data: UserAuthorityJsonMap): void {
  const value = data.affectedAssets;
  if (!Array.isArray(value) || value.length > 50) {
    malformed("charge-quality-abnormality", "affectedAssets");
  }
  const identities = new Set<string>();
  const inlineHierarchy = new Set<string>();
  value.forEach((raw, index) => {
    const parsed = linkedAffectedAssetEntry(
      raw,
      `affectedAssets[${index}]`,
      false,
    );
    if (identities.has(parsed.identity)) {
      malformed("charge-quality-abnormality", "affectedAssets");
    }
    identities.add(parsed.identity);
    if (parsed.hasHierarchy) inlineHierarchy.add(parsed.identity);
  });

  const hierarchyValue = data.affectedAssetHierarchyRefs;
  if (hierarchyValue === undefined) return;
  if (!Array.isArray(hierarchyValue) || hierarchyValue.length > value.length) {
    malformed("charge-quality-abnormality", "affectedAssetHierarchyRefs");
  }
  const hierarchyIdentities = new Set<string>();
  hierarchyValue.forEach((raw, index) => {
    const parsed = linkedAffectedAssetEntry(
      raw,
      `affectedAssetHierarchyRefs[${index}]`,
      true,
    );
    if (!identities.has(parsed.identity) ||
        inlineHierarchy.has(parsed.identity) ||
        hierarchyIdentities.has(parsed.identity)) {
      malformed("charge-quality-abnormality", "affectedAssetHierarchyRefs");
    }
    hierarchyIdentities.add(parsed.identity);
  });
}

function validateLinkedAbnormality(
  data: UserAuthorityJsonMap,
  abnormalityId: string,
  warning: UserAuthorityJsonMap,
  allowDeleted: boolean,
): UserAuthorityJsonMap {
  for (const key of Object.keys(data)) {
    if (!LINKED_ABNORMALITY_FIELDS.has(key)) {
      malformed("charge-quality-abnormality", key);
    }
  }
  for (const field of [...LINKED_ABNORMALITY_FIELDS].filter((value) =>
    value !== "_globalPullServerUpdatedAt" &&
      value !== "affectedAssetHierarchyRefs" &&
      !LEGACY_NULLABLE_CASE_FIELDS.has(value))) {
    if (!Object.prototype.hasOwnProperty.call(data, field)) {
      malformed("charge-quality-abnormality", field);
    }
  }
  if (data.firestoreId !== abnormalityId) {
    malformed("charge-quality-abnormality", "firestoreId");
  }
  if (typeof data.isDeleted !== "boolean") {
    malformed("charge-quality-abnormality", "isDeleted");
  }
  positiveExistingInteger(
    data.sourceChargeNo,
    "sourceChargeNo",
    "charge-quality-abnormality",
  );
  if (!isFiveDigitChargeNumber(data.sourceChargeNo) ||
      data.sourceChargeNo !== warning.sourceChargeNo) {
    malformed("charge-quality-abnormality", "sourceChargeNo");
  }
  validateLinkedAffectedAssets(data);
  positiveExistingInteger(
    data.version,
    "version",
    "charge-quality-abnormality",
  );
  requiredExistingString(
    data.abnormalityTypeId,
    "abnormalityTypeId",
    "charge-quality-abnormality",
    512,
  );
  requiredExistingString(
    data.abnormalityTypeTitle,
    "abnormalityTypeTitle",
    "charge-quality-abnormality",
    500,
  );
  requiredExistingString(
    data.abnormalityTypeCode,
    "abnormalityTypeCode",
    "charge-quality-abnormality",
    160,
  );
  if (typeof data.category !== "string" ||
      !ABNORMALITY_CATEGORIES.has(data.category)) {
    malformed("charge-quality-abnormality", "category");
  }
  if (typeof data.severity !== "string" ||
      !ABNORMALITY_SEVERITIES.has(data.severity)) {
    malformed("charge-quality-abnormality", "severity");
  }
  optionalExistingString(
    data.component,
    "component",
    "charge-quality-abnormality",
    200,
  );
  requiredExistingString(
    data.observedReason,
    "observedReason",
    "charge-quality-abnormality",
    2000,
  );
  optionalExistingString(
    data.description,
    "description",
    "charge-quality-abnormality",
    4000,
  );
  if (typeof data.possibleRootReasonCategory !== "string" ||
      !ABNORMALITY_ROOT_REASON_CATEGORIES.has(
        data.possibleRootReasonCategory,
      )) {
    malformed("charge-quality-abnormality", "possibleRootReasonCategory");
  }
  optionalExistingString(
    data.possibleRootReasonNotes,
    "possibleRootReasonNotes",
    "charge-quality-abnormality",
    4000,
  );
  requiredExistingString(
    data.loggedByUid,
    "loggedByUid",
    "charge-quality-abnormality",
    512,
  );
  optionalExistingString(
    data.loggedByName,
    "loggedByName",
    "charge-quality-abnormality",
    500,
  );
  requiredExistingString(
    data.updatedByUid,
    "updatedByUid",
    "charge-quality-abnormality",
    512,
  );
  optionalExistingString(
    data.updatedByName,
    "updatedByName",
    "charge-quality-abnormality",
    500,
  );
  optionalExistingString(
    data.linkedExecutionFirestoreId,
    "linkedExecutionFirestoreId",
    "charge-quality-abnormality",
    512,
  );
  if (!validDate(data.loggedAt) || !validDate(data.updatedAt) ||
      !REANNEALING_STATUSES.has(data.reannealingStatus as string)) {
    malformed("charge-quality-abnormality", "reannealingStatus");
  }
  if (dateMillis(data.updatedAt, "updatedAt", "charge-quality-abnormality") <
      dateMillis(data.loggedAt, "loggedAt", "charge-quality-abnormality")) {
    malformed("charge-quality-abnormality", "updatedAt");
  }
  if (data._globalPullServerUpdatedAt != null &&
      !validDate(data._globalPullServerUpdatedAt)) {
    malformed("charge-quality-abnormality", "_globalPullServerUpdatedAt");
  }
  const completed = data.reannealingStatus === "completed";
  const target = data.reannealedToChargeNo;
  if (completed !== (target != null) ||
      (target != null && (!isFiveDigitChargeNumber(target) ||
        target === data.sourceChargeNo))) {
    malformed("charge-quality-abnormality", "reannealedToChargeNo");
  }
  if (data.isDeleted === true) {
    if (!allowDeleted || !validDate(data.deletedAt)) {
      malformed("charge-quality-abnormality", "isDeleted");
    }
    requiredExistingString(
      data.deletedByUid,
      "deletedByUid",
      "charge-quality-abnormality",
      512,
    );
    requiredExistingString(
      data.deletedByName,
      "deletedByName",
      "charge-quality-abnormality",
      500,
    );
    requiredExistingString(
      data.deleteReason,
      "deleteReason",
      "charge-quality-abnormality",
      500,
    );
    const deletedMillis = dateMillis(
      data.deletedAt,
      "deletedAt",
      "charge-quality-abnormality",
    );
    if (deletedMillis <
        dateMillis(data.loggedAt, "loggedAt", "charge-quality-abnormality") ||
        deletedMillis >
        dateMillis(data.updatedAt, "updatedAt", "charge-quality-abnormality")) {
      malformed("charge-quality-abnormality", "deletedAt");
    }
  } else if (data.deletedAt != null || data.deletedByUid != null ||
      data.deletedByName != null || data.deleteReason != null) {
    malformed("charge-quality-abnormality", "isDeleted");
  }
  const expectedTicketId = warning.sourceType === "issue" ?
    warning.sourceId : null;
  if (data.linkedTicketFirestoreId !== expectedTicketId) {
    malformed("charge-quality-abnormality", "linkedTicketFirestoreId");
  }
  if (warning.sourceType === "abnormality") {
    // Affected assets name a set of physical subjects, and each identity is
    // already unique, so compare them canonically. Stored order is left
    // untouched: no command bytes or receipt fingerprints are rewritten.
    const warningAssetIdentities = (warning.affectedAssets as unknown[])
      .map((asset, index) => linkedAffectedAssetEntry(
        asset,
        `warning.affectedAssets[${index}]`,
        false,
      ).identity).sort();
    const abnormalityAssetIdentities = (data.affectedAssets as unknown[])
      .map((asset, index) => linkedAffectedAssetEntry(
        asset,
        `affectedAssets[${index}]`,
        false,
      ).identity).sort();
    if ((warning.sourceVersion as number) > (data.version as number) ||
        warning.sourceSummary !== data.abnormalityTypeTitle ||
        warning.sourceSeverity !== data.severity ||
        warning.warningReason !== data.observedReason ||
        // An absent optional key and an explicit null describe one value.
        (warning.component ?? null) !== (data.component ?? null) ||
        stableJson(warningAssetIdentities) !==
          stableJson(abnormalityAssetIdentities) ||
        dateMillis(
          warning.createdAt,
          "createdAt",
          "quality-warning",
        ) !== dateMillis(
          data.loggedAt,
          "loggedAt",
          "charge-quality-abnormality",
        ) ||
        warning.createdByUid !== data.loggedByUid ||
        (warning.createdByName ?? null) !== (data.loggedByName ?? null)) {
      malformed("charge-quality-case", "warningProjection");
    }
  }
  return {...data};
}

/**
 * The contract every trusted producer of a quality case owes the adjudication
 * path: whatever it is about to commit must read back through exactly the
 * validation a quality decision will apply to it. A case that could not be
 * adjudicated is refused at the moment it would be created, rather than
 * becoming a record no operator can close.
 */
export function validateQualityCasePostcondition(plan: {
  readonly warningId: string;
  readonly warning: UserAuthorityJsonMap;
  readonly abnormalityId: string | null;
  readonly abnormality: UserAuthorityJsonMap | null;
}): void {
  const warning = validateQualityWarningRecord(plan.warning, plan.warningId);
  if (plan.abnormality == null || plan.abnormalityId == null) {
    // A standalone case is its abnormality; an issue-origin case may legitimately
    // carry none, and then nothing links to validate.
    if (warning.sourceType === "abnormality") {
      malformed("charge-quality-case", "linkedAbnormality");
    }
    return;
  }
  validateLinkedAbnormality(
    plan.abnormality,
    plan.abnormalityId,
    warning,
    false,
  );
}

type LinkedAbnormality = {
  readonly id: string;
  readonly ref: DocumentRefLike;
  readonly before: UserAuthorityJsonMap;
};

function warningHasGovernedAssetEvidence(
  warning: UserAuthorityJsonMap,
): boolean {
  if (!Array.isArray(warning.affectedAssets)) return false;
  return warning.affectedAssets.some((raw) =>
    raw != null && typeof raw === "object" && !Array.isArray(raw) &&
    Object.prototype.hasOwnProperty.call(raw, "assetHierarchyRef"));
}

async function linkedAbnormalityForWarning(args: {
  db: QualityMutationFirestoreLike;
  transaction: TransactionLike;
  warning: UserAuthorityJsonMap;
  allowDeleted: boolean;
}): Promise<LinkedAbnormality | null> {
  const {db, transaction, warning, allowDeleted} = args;
  let abnormalityId: string | null = null;
  if (warning.sourceType === "abnormality") {
    abnormalityId = warning.sourceId as string;
  } else {
    const ticketId = warning.sourceId as string;
    const governedIssueCase = warningHasGovernedAssetEvidence(warning);
    const expectedAbnormalityId = `issue_quality_${ticketId}`;
    const ticketSnapshot = await transaction.get(
      db.collection("maintenance_records").doc(ticketId),
    );
    if (!ticketSnapshot.exists) {
      if (governedIssueCase) {
        throw new QualityMutationError(
          "data-loss",
          "The governed quality warning is missing its source issue and linked charge abnormality.",
          {
            reasonCode: "charge-quality-abnormality-missing",
            abnormalityId: expectedAbnormalityId,
          },
        );
      }
      return null;
    }
    const ticket = ticketSnapshot.data() ?? {};
    const linkValues = [
      ticket.qualityAbnormalityId,
      ticket.qualityWarningId,
      ticket.chargeQualityCaseId,
    ];
    if (linkValues.every((value) => value == null)) {
      if (governedIssueCase) {
        throw new QualityMutationError(
          "data-loss",
          "The governed quality warning is missing its linked charge abnormality.",
          {
            reasonCode: "charge-quality-abnormality-missing",
            abnormalityId: expectedAbnormalityId,
          },
        );
      }
      return null;
    }
    const expectedWarningId = `issue_${ticketId}`;
    if (ticket.qualityAbnormalityId !== expectedAbnormalityId ||
        ticket.qualityWarningId !== expectedWarningId ||
        ticket.chargeQualityCaseId !== expectedWarningId ||
        warning.warningId !== expectedWarningId) {
      malformed("charge-quality-case", "qualityAbnormalityId");
    }
    abnormalityId = expectedAbnormalityId;
  }
  const ref = db.collection("charge_abnormalities").doc(abnormalityId);
  const snapshot = await transaction.get(ref);
  if (!snapshot.exists) {
    throw new QualityMutationError(
      "data-loss",
      "The quality warning is missing its linked charge abnormality.",
      {reasonCode: "charge-quality-abnormality-missing", abnormalityId},
    );
  }
  return {
    id: abnormalityId,
    ref,
    before: validateLinkedAbnormality(
      snapshot.data() ?? {},
      abnormalityId,
      warning,
      allowDeleted,
    ),
  };
}

export function validateQualityMonitoringRecord(
  data: UserAuthorityJsonMap,
  requestId: string,
): UserAuthorityJsonMap {
  for (const key of Object.keys(data)) {
    if (!MONITORING_FIELDS.has(key) && !(data.schemaVersion === 4 && MONITORING_REVIEW_FIELDS.has(key))) malformed("quality-monitoring", key);
  }
  const schemaVersion = data.schemaVersion;
  if (schemaVersion !== 1 && schemaVersion !== 2 && schemaVersion !== 3 && schemaVersion !== 4) {
    malformed("quality-monitoring", "schemaVersion");
  }
  const visibilityFieldCount = [...MONITORING_VISIBILITY_FIELDS]
    .filter((field) => Object.prototype.hasOwnProperty.call(data, field)).length;
  const baseIdentityFieldCount = [...MONITORING_BASE_IDENTITY_FIELDS]
    .filter((field) => Object.prototype.hasOwnProperty.call(data, field)).length;
  if ((schemaVersion === 1 && visibilityFieldCount !== 0) ||
      (schemaVersion >= 2 &&
        visibilityFieldCount !== MONITORING_VISIBILITY_FIELDS.size)) {
    malformed("quality-monitoring", "visibilityState");
  }
  // Cancelling a legacy instruction must not invent a registered Base identity.
  const legacyCancellation = schemaVersion === 4 && data.monitoringDisposition === "cancelled" &&
    baseIdentityFieldCount === 0;
  if ((schemaVersion < 3 && baseIdentityFieldCount !== 0) ||
      (schemaVersion >= 3 && !legacyCancellation &&
        baseIdentityFieldCount !== MONITORING_BASE_IDENTITY_FIELDS.size)) {
    malformed("quality-monitoring", "baseAssetInstanceId");
  }
  for (const field of [...MONITORING_FIELDS].filter((value) =>
    value !== "_globalPullServerUpdatedAt")) {
    if (schemaVersion === 1 && MONITORING_VISIBILITY_FIELDS.has(field)) {
      continue;
    }
    if ((schemaVersion < 3 || legacyCancellation) && MONITORING_BASE_IDENTITY_FIELDS.has(field)) {
      continue;
    }
    if (!Object.prototype.hasOwnProperty.call(data, field)) {
      malformed("quality-monitoring", field);
    }
  }
  if (data.requestId !== requestId) {
    malformed("quality-monitoring", "requestId");
  }
  positiveExistingInteger(data.baseNumber, "baseNumber", "quality-monitoring");
  if (schemaVersion >= 3 && !legacyCancellation) {
    requiredExistingString(
      data.baseAssetClassId,
      "baseAssetClassId",
      "quality-monitoring",
      512,
    );
    requiredExistingString(
      data.baseAssetInstanceId,
      "baseAssetInstanceId",
      "quality-monitoring",
      512,
    );
    positiveExistingInteger(
      data.baseAssetInstanceVersion,
      "baseAssetInstanceVersion",
      "quality-monitoring",
    );
  }
  requiredExistingString(data.grade, "grade", "quality-monitoring");
  requiredExistingString(data.cycleReference, "cycleReference", "quality-monitoring");
  requiredExistingString(data.reason, "reason", "quality-monitoring");
  if (!Array.isArray(data.chargeNumbers) || data.chargeNumbers.length > 50) {
    malformed("quality-monitoring", "chargeNumbers");
  }
  const charges = data.chargeNumbers.map((value, index) =>
    positiveExistingInteger(
      value,
      `chargeNumbers[${index}]`,
      "quality-monitoring",
    ));
  if (charges.some((chargeNo) => !isFiveDigitChargeNumber(chargeNo)) ||
      new Set(charges).size !== charges.length) {
    malformed("quality-monitoring", "chargeNumbers");
  }
  if (data.status !== "active" && data.status !== "closed") {
    malformed("quality-monitoring", "status");
  }
  positiveExistingInteger(data.version, "version", "quality-monitoring");
  requiredExistingString(data.createdByUid, "createdByUid", "quality-monitoring");
  requiredExistingString(data.createdByName, "createdByName", "quality-monitoring");
  requiredExistingString(data.updatedByUid, "updatedByUid", "quality-monitoring");
  requiredExistingString(data.updatedByName, "updatedByName", "quality-monitoring");
  if (typeof data.lastMutationId !== "string" || !UUID.test(data.lastMutationId)) {
    malformed("quality-monitoring", "lastMutationId");
  }
  if (!validDate(data.createdAt) || !validDate(data.updatedAt)) {
    malformed("quality-monitoring", "updatedAt");
  }
  const createdAtMillis = dateMillis(
    data.createdAt,
    "createdAt",
    "quality-monitoring",
  );
  const updatedAtMillis = dateMillis(
    data.updatedAt,
    "updatedAt",
    "quality-monitoring",
  );
  if (updatedAtMillis < createdAtMillis) {
    malformed("quality-monitoring", "updatedAt");
  }
  if (data._globalPullServerUpdatedAt != null &&
      !validDate(data._globalPullServerUpdatedAt)) {
    malformed("quality-monitoring", "_globalPullServerUpdatedAt");
  }
  const closedAt = optionalExistingDate(
    data.closedAt,
    "closedAt",
    "quality-monitoring",
  );
  const closureEvidence = [
    closedAt,
    optionalExistingString(data.closedByUid, "closedByUid", "quality-monitoring"),
    optionalExistingString(data.closedByName, "closedByName", "quality-monitoring"),
    optionalExistingString(data.closeReason, "closeReason", "quality-monitoring"),
  ];
  const closureEvidenceCount = closureEvidence.filter((value) => value != null).length;
  if ((data.status === "active" && closureEvidenceCount !== 0) ||
      (data.status === "closed" &&
        closureEvidenceCount !== closureEvidence.length)) {
    malformed("quality-monitoring", "status");
  }
  if (closedAt != null) {
    const closedAtMillis = dateMillis(
      closedAt,
      "closedAt",
      "quality-monitoring",
    );
    if (closedAtMillis < createdAtMillis || closedAtMillis > updatedAtMillis) {
      malformed("quality-monitoring", "closedAt");
    }
  }
  const visibilityState = schemaVersion === 1 ?
    (data.status === "active" ? "active" : "recent") : data.visibilityState;
  if (visibilityState !== "active" &&
      visibilityState !== "recent" &&
      visibilityState !== "archived") {
    malformed("quality-monitoring", "visibilityState");
  }
  const visibleUntil = schemaVersion === 1 ?
    (closedAt == null ? null : new Date(
      dateMillis(closedAt, "closedAt", "quality-monitoring") +
        QUALITY_MONITORING_OPERATIONAL_RETENTION_MS,
    )) : optionalExistingDate(
      data.visibleUntil,
      "visibleUntil",
      "quality-monitoring",
    );
  const archivedAt = schemaVersion === 1 ? null : optionalExistingDate(
    data.archivedAt,
    "archivedAt",
    "quality-monitoring",
  );
  if (data.status === "active") {
    if (visibilityState !== "active" ||
        visibleUntil != null || archivedAt != null) {
      malformed("quality-monitoring", "visibilityState");
    }
  } else if (visibilityState === "recent") {
    if (closedAt == null || visibleUntil == null || archivedAt != null ||
        dateMillis(visibleUntil, "visibleUntil", "quality-monitoring") !==
          dateMillis(closedAt, "closedAt", "quality-monitoring") +
            QUALITY_MONITORING_OPERATIONAL_RETENTION_MS) {
      malformed("quality-monitoring", "visibleUntil");
    }
  } else if (visibilityState === "archived") {
    if (closedAt == null || visibleUntil != null || archivedAt == null ||
        dateMillis(archivedAt, "archivedAt", "quality-monitoring") <
          dateMillis(closedAt, "closedAt", "quality-monitoring") +
            QUALITY_MONITORING_OPERATIONAL_RETENTION_MS) {
      malformed("quality-monitoring", "archivedAt");
    }
  } else {
    malformed("quality-monitoring", "visibilityState");
  }
  if (schemaVersion === 4) {
    const expected = data.status === "active" ? [null] : ["completed", "cancelled"];
    if (!Object.prototype.hasOwnProperty.call(data, "monitoringDisposition") ||
        !(expected as unknown[]).includes(data.monitoringDisposition)) malformed("quality-monitoring", "monitoringDisposition");
    const context = data.originalMonitoringContext;
    if (context == null || typeof context !== "object" || Array.isArray(context) ||
        Object.keys(context).sort().join(",") !== [...MONITORING_CONTEXT_FIELDS].sort().join(",")) {
      malformed("quality-monitoring", "originalMonitoringContext");
    }
    const raw = context as UserAuthorityJsonMap;
    const identityAbsent = [...MONITORING_BASE_IDENTITY_FIELDS].every((field) => raw[field] === null);
    if ((raw.baseAssetClassId == null && !identityAbsent) || (legacyCancellation && !identityAbsent)) {
      malformed("quality-monitoring", "originalMonitoringContext");
    }
    // Reuse the established context contract, including legacy null identity.
    const original: UserAuthorityJsonMap = {...data, ...raw, schemaVersion: raw.baseAssetClassId == null ? 2 : 3};
    delete original.originalMonitoringContext;
    delete original.monitoringDisposition;
    if (raw.baseAssetClassId == null) {
      delete original.baseAssetClassId; delete original.baseAssetInstanceId; delete original.baseAssetInstanceVersion;
    }
    validateQualityMonitoringRecord(original, requestId);
  }
  return {...data, visibilityState, visibleUntil, archivedAt};
}

function requiredExistingString(
  value: unknown,
  field: string,
  entity: string,
  maximum = Number.MAX_SAFE_INTEGER,
): string {
  if (typeof value !== "string" || value.trim().length === 0 ||
      value.trim().length > maximum) {
    malformed(entity, field);
  }
  return (value as string).trim();
}

function optionalExistingString(
  value: unknown,
  field: string,
  entity: string,
  maximum = Number.MAX_SAFE_INTEGER,
): string | null {
  return value == null ? null :
    requiredExistingString(value, field, entity, maximum);
}

function optionalExistingDate(
  value: unknown,
  field: string,
  entity: string,
): unknown | null {
  if (value == null) return null;
  if (!validDate(value)) malformed(entity, field);
  return value;
}

function positiveExistingInteger(
  value: unknown,
  field: string,
  entity: string,
): number {
  if (!Number.isSafeInteger(value) || (value as number) <= 0) {
    malformed(entity, field);
  }
  return value as number;
}

function targetIdentity(request: ParsedRequest): string {
  return "warningId" in request ? request.warningId : request.monitoringRequestId;
}

type MonitoringBaseIdentity = {
  classId: string;
  instanceId: string;
  expectedInstanceVersion: number | null;
};

function isActiveBaseCandidate(
  asset: UserAuthorityJsonMap,
  assetDocumentId: string | undefined,
  assetClass: UserAuthorityJsonMap,
  baseNumber: number,
): boolean {
  const instanceId = asset.assetInstanceId;
  const classId = asset.assetClassId;
  return asset.schemaVersion === 1 &&
    typeof instanceId === "string" &&
    (assetDocumentId == null || assetDocumentId === instanceId) &&
    typeof classId === "string" &&
    asset.assetNumber === baseNumber &&
    asset.status === "active" &&
    assetClass.schemaVersion === 1 &&
    assetClass.assetClassId === classId &&
    assetClass.status === "active" &&
    assetClass.legacyAssetTypeKey === "base";
}

async function resolveMonitoringBaseIdentity(args: {
  db: QualityMutationFirestoreLike;
  request: ParsedMonitoringRequest;
}): Promise<MonitoringBaseIdentity> {
  const {db, request} = args;
  if (request.baseAssetClassId != null &&
      request.baseAssetInstanceId != null &&
      request.baseAssetInstanceVersion != null) {
    return {
      classId: request.baseAssetClassId,
      instanceId: request.baseAssetInstanceId,
      expectedInstanceVersion: request.baseAssetInstanceVersion,
    };
  }
  const baseNumber = request.baseNumber;
  if (baseNumber == null) {
    throw new QualityMutationError(
      "invalid-argument",
      "A Base number is required for monitoring creation.",
      {reasonCode: "quality-monitoring-base-number-missing"},
    );
  }
  const assets = db.collection("asset_instances");
  if (assets.where == null) {
    throw new QualityMutationError(
      "internal",
      "The governed Base register could not be queried.",
      {reasonCode: "quality-monitoring-base-query-unavailable"},
    );
  }
  // A legacy number-only request cannot certify uniqueness from a capped
  // sample. Read the complete number population before deciding whether the
  // governed Base is missing, unique or ambiguous.
  const candidates = await assets
    .where("assetNumber", "==", baseNumber)
    .get();
  const matches: MonitoringBaseIdentity[] = [];
  for (const snapshot of candidates.docs) {
    if (!snapshot.exists) continue;
    const asset = snapshot.data() ?? {};
    const classId = asset.assetClassId;
    const instanceId = asset.assetInstanceId;
    if (typeof classId !== "string" || typeof instanceId !== "string") {
      continue;
    }
    const classSnapshot = await db.collection("asset_classes").doc(classId).get();
    if (!classSnapshot.exists) continue;
    const assetClass = classSnapshot.data() ?? {};
    if (isActiveBaseCandidate(asset, snapshot.id, assetClass, baseNumber)) {
      matches.push({
        classId,
        instanceId,
        expectedInstanceVersion: null,
      });
    }
  }
  if (matches.length !== 1) {
    throw new QualityMutationError(
      "failed-precondition",
      matches.length === 0 ?
        `Base ${baseNumber} is not an active governed asset.` :
        `Base ${baseNumber} is ambiguous in the governed asset register.`,
      {
        reasonCode: matches.length === 0 ?
          "quality-monitoring-base-not-found" :
          "quality-monitoring-base-ambiguous",
        baseNumber,
        matchCount: matches.length,
      },
    );
  }
  return matches[0];
}

function certifyMonitoringBase(args: {
  request: ParsedMonitoringRequest;
  identity: MonitoringBaseIdentity;
  classSnapshot: SnapshotLike;
  assetSnapshot: SnapshotLike;
}): {instanceVersion: number} {
  const {request, identity, classSnapshot, assetSnapshot} = args;
  const assetClass = classSnapshot.data() ?? {};
  const asset = assetSnapshot.data() ?? {};
  const baseNumber = request.baseNumber;
  if (!classSnapshot.exists || !assetSnapshot.exists || baseNumber == null ||
      !isActiveBaseCandidate(
        asset,
        assetSnapshot.id,
        assetClass,
        baseNumber,
      ) ||
      asset.assetClassId !== identity.classId ||
      asset.assetInstanceId !== identity.instanceId ||
      typeof assetClass.code !== "string" ||
      typeof assetClass.name !== "string" ||
      asset.assetClassCode !== assetClass.code ||
      typeof asset.assetClassName !== "string" || asset.assetClassName.trim().length === 0 ||
      assetClass.name.trim().length === 0 ||
      typeof asset.name !== "string" ||
      !Number.isSafeInteger(asset.version) ||
      (asset.version as number) < 1) {
    throw new QualityMutationError(
      "failed-precondition",
      "The selected Base identity is missing, retired, or inconsistent.",
      {reasonCode: "quality-monitoring-base-invalid"},
    );
  }
  const instanceVersion = asset.version as number;
  if (identity.expectedInstanceVersion != null &&
      identity.expectedInstanceVersion !== instanceVersion) {
    throw new QualityMutationError(
      "aborted",
      "The selected Base changed before monitoring was created. Refresh and select it again.",
      {
        reasonCode: "quality-monitoring-base-version-mismatch",
        currentVersion: instanceVersion,
      },
    );
  }
  return {instanceVersion};
}

function monitoringCreationFingerprint(request: ParsedRequest): string {
  return request.fingerprint.replace("qualityreq1-sha256:", "qualitycreate2-sha256:");
}

function auditEvidenceDigest(audit: UserAuthorityJsonMap): string {
  const {timestamp: _timestamp, ...evidence} = audit;
  return createHash("sha256").update(stableJson(evidence), "utf8").digest("hex");
}

// Creation commits are server-generated millisecond instants. Exact evidence
// checks must not discard malformed string forms or sub-millisecond drift.
function creationTimeMillis(value: unknown): number {
  if (value instanceof Date) return value.valueOf();
  if (typeof value === "string") {
    if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value)) return NaN;
    const date = new Date(value);
    return Number.isFinite(date.valueOf()) && date.toISOString() === value ? date.valueOf() : NaN;
  }
  if (value == null || typeof value !== "object") return NaN;
  const raw = value as UserAuthorityJsonMap;
  const seconds = raw.seconds ?? raw._seconds;
  const nanos = raw.nanoseconds ?? raw._nanoseconds;
  if (!Number.isSafeInteger(seconds) || !Number.isSafeInteger(nanos) ||
      (nanos as number) < 0 || (nanos as number) >= 1_000_000_000 || (nanos as number) % 1_000_000 !== 0 ||
      (raw.seconds != null && raw._seconds != null && raw.seconds !== raw._seconds) ||
      (raw.nanoseconds != null && raw._nanoseconds != null && raw.nanoseconds !== raw._nanoseconds)) return NaN;
  const millis = (seconds as number) * 1000 + (nanos as number) / 1_000_000;
  return Number.isSafeInteger(millis) && Number.isFinite(new Date(millis).valueOf()) ? millis : NaN;
}

function replayMonitoringCreation(args: {
  request: ParsedMonitoringRequest;
  actorUid: string;
  receipt: UserAuthorityJsonMap;
  audit: UserAuthorityJsonMap;
  current: UserAuthorityJsonMap;
  auditId: string;
}): QualityMutationResult {
  const {request, actorUid, receipt, audit, current, auditId} = args;
  const fail = (): never => { throw new QualityMutationError("data-loss",
    "Original monitoring creation evidence is incomplete or inconsistent.",
    {reasonCode: "quality-monitoring-creation-replay-invalid"}); };
  const modern = receipt.payloadFingerprint === monitoringCreationFingerprint(request);
  if ((modern && (receipt.creationEvidenceVersion !== 2 || audit.creationEvidenceVersion !== 2 ||
      audit.payloadFingerprint !== receipt.payloadFingerprint || receipt.creationAuditSha256 !== auditEvidenceDigest(audit))) ||
      (!modern && (receipt.creationEvidenceVersion != null || audit.creationEvidenceVersion != null ||
        receipt.creationAuditSha256 != null || audit.payloadFingerprint != null))) fail();
  const committed = creationTimeMillis(receipt.committedAtIso);
  if (!Number.isFinite(committed) || receipt.schemaVersion !== 1 || receipt.requestId !== request.requestId ||
      receipt.expectedVersion !== 0 || receipt.resultVersion !== 1 || receipt.auditId !== auditId ||
      receipt.linkedAbnormalityId !== null || receipt.linkedAbnormalityVersion !== null ||
      creationTimeMillis(receipt.committedAt) !== committed || audit.schemaVersion !== 1 ||
      audit.eventType !== "qualityMutation" || audit.entityType !== "quality_monitoring_request" ||
      audit.entityId !== request.monitoringRequestId || audit.action !== "create" || audit.severity !== "high" ||
      audit.performedByUid !== actorUid || typeof audit.performedByName !== "string" || audit.performedByName.trim().length === 0 ||
      creationTimeMillis(audit.timestamp) !== committed || audit.reason !== "other" || audit.reasonNotes !== request.reason ||
      audit.summary !== "Quality command CREATE_QUALITY_MONITORING_REQUEST" || audit.beforeJson !== null ||
      audit.requestId !== request.requestId || audit.operation !== request.operation || audit.expectedVersion !== 0 || audit.resultVersion !== 1 ||
      audit.linkedAbnormalityId !== null || audit.linkedAbnormalityBeforeVersion !== null || audit.linkedAbnormalityResultVersion !== null ||
      typeof audit.afterJson !== "string") fail();
  let parsed: unknown;
  try { parsed = JSON.parse(audit.afterJson as string); } catch (_) { fail(); }
  if (parsed == null || typeof parsed !== "object" || Array.isArray(parsed)) fail();
  let original: UserAuthorityJsonMap;
  try { original = validateQualityMonitoringRecord(parsed as UserAuthorityJsonMap, request.monitoringRequestId); }
  catch (_) { return fail(); }
  // Validation may derive visibility fields for schema-1 data, but replay
  // must preserve the historical payload shape that the old client accepted.
  const historicalOriginal = {...(parsed as UserAuthorityJsonMap)};
  if (original.version !== 1 || original.status !== "active" || original.lastMutationId !== request.requestId ||
      original.createdByUid !== actorUid || original.updatedByUid !== actorUid ||
      original.createdByName !== audit.performedByName || original.updatedByName !== audit.performedByName ||
      creationTimeMillis(original.createdAt) !== committed || creationTimeMillis(original.updatedAt) !== committed ||
      original.baseNumber !== request.baseNumber || original.grade !== request.grade || original.cycleReference !== request.cycleReference ||
      original.reason !== request.reason || stableJson(original.chargeNumbers) !== stableJson(request.chargeNumbers) ||
      (request.baseAssetClassId != null && (original.baseAssetClassId !== request.baseAssetClassId ||
        original.baseAssetInstanceId !== request.baseAssetInstanceId || original.baseAssetInstanceVersion !== request.baseAssetInstanceVersion))) fail();
  // The later record is checked for immutable creation identity only. Legitimate
  // closure/archive state cannot rewrite or block acknowledgement of creation A.
  for (const field of ["requestId", "baseNumber", "grade", "cycleReference", "chargeNumbers", "reason",
    "createdByUid", "createdByName", "baseAssetClassId", "baseAssetInstanceId", "baseAssetInstanceVersion"]) {
    const actual = current.schemaVersion === 4 && MONITORING_CONTEXT_FIELDS.includes(field) ?
      (current.originalMonitoringContext as UserAuthorityJsonMap)[field] : current[field];
    if (stableJson(original[field] ?? null) !== stableJson(actual ?? null)) fail();
  }
  if ((current.version as number) < 1 || creationTimeMillis(current.createdAt) !== committed) fail();
  return {ok: true, requestId: request.requestId, operation: request.operation,
    entityId: request.monitoringRequestId, version: 1, auditId,
    committedAt: receipt.committedAtIso as string, idempotentReplay: true,
    entity: historicalOriginal, linkedAbnormality: null};
}

function replayResult(args: {
  request: ParsedRequest;
  actorUid: string;
  receipt: UserAuthorityJsonMap;
  audit: UserAuthorityJsonMap | null;
  target: UserAuthorityJsonMap | null;
  linkedAbnormality: LinkedAbnormality | null;
  auditId: string;
}): QualityMutationResult {
  const {
    request,
    actorUid,
    receipt,
    audit,
    target,
    linkedAbnormality,
    auditId,
  } = args;
  const entityId = targetIdentity(request);
  if ((receipt.payloadFingerprint !== request.fingerprint &&
        !(request.operation === "CREATE_QUALITY_MONITORING_REQUEST" && receipt.payloadFingerprint === monitoringCreationFingerprint(request))) ||
      receipt.actorUid !== actorUid ||
      receipt.entityId !== entityId ||
      receipt.operation !== request.operation) {
    throw new QualityMutationError(
      "aborted",
      "requestId is already bound to another quality mutation.",
      {reasonCode: "quality-request-id-conflict"},
    );
  }
  if (audit == null || target == null) {
    throw new QualityMutationError(
      "data-loss",
      "Quality replay evidence is incomplete.",
      {reasonCode: "quality-replay-evidence-missing"},
    );
  }
  const current = "warningId" in request ?
    validateQualityWarningRecord(target, entityId) :
    validateQualityMonitoringRecord(target, entityId);
  if (request.operation === "CREATE_QUALITY_MONITORING_REQUEST") {
    return replayMonitoringCreation({request: request as ParsedMonitoringRequest,
      actorUid, receipt, audit, current, auditId});
  }
  if (request.operation === "CORRECT_QUALITY_MONITORING_REQUEST" || request.operation === "CANCEL_QUALITY_MONITORING_REQUEST") {
    if (receipt.schemaVersion !== 1 || receipt.requestId !== request.requestId ||
        audit.schemaVersion !== 1 || audit.eventType !== "qualityMutation" || audit.entityType !== "quality_monitoring_request" ||
        audit.action !== qualityAuditActionForOperation(request.operation) ||
        creationTimeMillis(receipt.committedAt) !== creationTimeMillis(receipt.committedAtIso) ||
        receipt.acceptedEvidenceVersion !== 2 || receipt.acceptedAuditSha256 !== auditEvidenceDigest(audit) ||
        receipt.resultVersion !== request.expectedVersion + 1 || receipt.expectedVersion !== request.expectedVersion ||
        receipt.auditId !== auditId || audit.requestId !== request.requestId || audit.entityId !== entityId ||
        audit.operation !== request.operation || audit.performedByUid !== actorUid ||
        audit.reasonNotes !== request.reason || typeof audit.afterJson !== "string" ||
        audit.resultVersion !== receipt.resultVersion || audit.expectedVersion !== request.expectedVersion ||
        creationTimeMillis(audit.timestamp) !== creationTimeMillis(receipt.committedAtIso)) return qualityReplayEvidenceMalformed();
    let accepted: UserAuthorityJsonMap;
    try { accepted = validateQualityMonitoringRecord(JSON.parse(audit.afterJson), entityId); }
    catch (_) { return qualityReplayEvidenceMalformed(); }
    if (!sameInstant(accepted.updatedAt, receipt.committedAtIso) || accepted.updatedByName !== audit.performedByName ||
        accepted.version !== receipt.resultVersion || accepted.lastMutationId !== request.requestId ||
        accepted.updatedByUid !== actorUid || (current.version as number) < (accepted.version as number) ||
        current.createdByUid !== accepted.createdByUid || !sameInstant(current.createdAt, accepted.createdAt)) return qualityReplayEvidenceMalformed();
    if (request.operation === "CANCEL_QUALITY_MONITORING_REQUEST" &&
        (accepted.monitoringDisposition !== "cancelled" || accepted.closeReason !== request.reason ||
          accepted.closedByUid !== actorUid || !sameInstant(accepted.closedAt, receipt.committedAtIso))) return qualityReplayEvidenceMalformed();
    if (request.operation === "CORRECT_QUALITY_MONITORING_REQUEST" &&
        (accepted.status !== "active" || MONITORING_CONTEXT_FIELDS.filter((field) => field !== "reason").some((field) =>
          stableJson(accepted[field]) !== stableJson((request as unknown as UserAuthorityJsonMap)[field])))) return qualityReplayEvidenceMalformed();
    if (current.version === accepted.version && !qualityRecordsMatch(
      {...accepted, visibilityState: null, visibleUntil: null, archivedAt: null},
      {...current, visibilityState: null, visibleUntil: null, archivedAt: null},
      new Set(["createdAt", "updatedAt", "closedAt"]))) return qualityReplayEvidenceMalformed();
    return {ok: true, requestId: request.requestId, operation: request.operation, entityId,
      version: accepted.version as number, auditId, committedAt: receipt.committedAtIso as string,
      idempotentReplay: true, entity: accepted, linkedAbnormality: null};
  }
  if (request.operation === "CLOSE_QUALITY_MONITORING_REQUEST") {
    // A close replay is allowed to observe later archival visibility, but it
    // must still prove the immutable close accepted by the original command.
    if (receipt.schemaVersion !== 1 || receipt.requestId !== request.requestId ||
        receipt.expectedVersion !== request.expectedVersion ||
        receipt.resultVersion !== request.expectedVersion + 1 || receipt.auditId !== auditId ||
        audit.schemaVersion !== 1 || audit.eventType !== "qualityMutation" ||
        audit.entityType !== "quality_monitoring_request" || audit.entityId !== entityId ||
        audit.requestId !== request.requestId ||
        creationTimeMillis(receipt.committedAt) !== creationTimeMillis(receipt.committedAtIso) ||
        (receipt.acceptedEvidenceVersion === 2 &&
          receipt.acceptedAuditSha256 !== auditEvidenceDigest(audit))) {
      return qualityReplayEvidenceMalformed();
    }
    let acceptedAfter: UserAuthorityJsonMap;
    try {
      if (audit.action !== "resolve" ||
          audit.operation !== request.operation ||
          audit.performedByUid !== actorUid ||
          audit.reasonNotes !== request.reason ||
          audit.expectedVersion !== request.expectedVersion ||
          audit.resultVersion !== receipt.resultVersion ||
          typeof audit.afterJson !== "string") {
        return qualityReplayEvidenceMalformed();
      }
      const parsedAfter = JSON.parse(audit.afterJson as string);
      if (parsedAfter == null || typeof parsedAfter !== "object" || Array.isArray(parsedAfter)) {
        return qualityReplayEvidenceMalformed();
      }
      acceptedAfter = validateQualityMonitoringRecord(
        parsedAfter as UserAuthorityJsonMap,
        entityId,
      );
    } catch (_) {
      return qualityReplayEvidenceMalformed();
    }
    if (acceptedAfter.status !== "closed" ||
        acceptedAfter.version !== receipt.resultVersion ||
        acceptedAfter.closedByUid !== actorUid ||
        acceptedAfter.closeReason !== request.reason ||
        creationTimeMillis(acceptedAfter.closedAt) !== creationTimeMillis(receipt.committedAt) ||
        creationTimeMillis(audit.timestamp) !== creationTimeMillis(receipt.committedAt)) {
      return qualityReplayEvidenceMalformed();
    }
    // Visibility is a projection: archival may change it without changing the
    // accepted business record. Everything else must still match at this tip.
    const business = (row: UserAuthorityJsonMap): UserAuthorityJsonMap => {
      const {visibilityState: _visibility, visibleUntil: _until, archivedAt: _archived, ...rest} = row;
      return rest;
    };
    if (!qualityRecordsMatch(business(acceptedAfter), business(current),
      new Set(["createdAt", "updatedAt", "closedAt"]))) {
      return qualityReplayEvidenceMalformed();
    }
    return {
      ok: true,
      requestId: request.requestId,
      operation: request.operation,
      entityId,
      version: receipt.resultVersion as number,
      auditId,
      committedAt: receipt.committedAtIso as string,
      idempotentReplay: true,
      entity: acceptedAfter,
      linkedAbnormality: null,
    };
  }
  const hasLinkedEvidence = Object.prototype.hasOwnProperty.call(
    receipt,
    "linkedAbnormalityId",
  ) || Object.prototype.hasOwnProperty.call(
    receipt,
    "linkedAbnormalityVersion",
  );
  if (hasLinkedEvidence &&
      receipt.linkedAbnormalityId !== (linkedAbnormality?.id ?? null)) {
    return linkedAbnormalityReplayDrift();
  }
  const resultVersion = receipt.resultVersion;
  if (receipt.schemaVersion !== 1 ||
      receipt.auditId !== auditId ||
      audit.schemaVersion !== 1 ||
      audit.eventType !== "qualityMutation" ||
      audit.requestId !== request.requestId ||
      audit.entityId !== entityId ||
      !Number.isSafeInteger(resultVersion) ||
      (current.version as number) < (resultVersion as number)) {
    return qualityReplayEvidenceMalformed();
  }
  // The receipt proves what was accepted. Later legitimate work may advance
  // the warning or its linked case, but neither may fall behind that result.
  const linkedVersion = receipt.linkedAbnormalityVersion;
  if (hasLinkedEvidence && linkedAbnormality != null &&
      (!Number.isSafeInteger(linkedVersion) ||
        (linkedAbnormality.before.version as number) <
          (linkedVersion as number))) {
    return linkedAbnormalityReplayDrift();
  }
  const linkedUnchanged = !hasLinkedEvidence || linkedAbnormality == null ||
    linkedAbnormality.before.version === linkedVersion;
  if (!("warningId" in request)) {
    // Monitoring requests keep strict tip evidence; creation recovers above.
    if (current.version !== resultVersion ||
        current.lastMutationId !== request.requestId) {
      return qualityReplayEvidenceMalformed();
    }
    return {
      ok: true,
      requestId: request.requestId,
      operation: request.operation,
      entityId,
      version: current.version as number,
      auditId,
      committedAt: receipt.committedAtIso as string,
      idempotentReplay: true,
      entity: current,
      linkedAbnormality: null,
    };
  }
  if (receipt.acceptedEvidenceVersion === 2 &&
      (typeof receipt.acceptedAuditSha256 !== "string" ||
        receipt.acceptedAuditSha256 !== auditEvidenceDigest(audit))) {
    return qualityReplayEvidenceMalformed();
  }
  // The accepted decision is always re-derived from the immutable audit and
  // bound to this frozen command, whether or not the case has moved on.
  const accepted = acceptedWarningFromAudit({
    audit,
    receipt,
    current,
    request,
    actorUid,
    entityId,
  });
  const acceptedLinked = acceptedLinkedAbnormality({
    audit,
    receipt,
    request,
    actorUid,
    accepted,
    linkedAbnormality,
    linkedUnchanged,
  });
  if (current.version === resultVersion && linkedUnchanged) {
    if (current.lastMutationId !== request.requestId ||
        !qualityRecordsMatch(accepted, current, WARNING_DATE_FIELDS) ||
        (acceptedLinked != null && linkedAbnormality != null &&
          !qualityRecordsMatch(
            acceptedLinked,
            linkedAbnormality.before,
            LINKED_DATE_FIELDS,
          ))) {
      return qualityReplayEvidenceMalformed();
    }
    return {
      ok: true,
      requestId: request.requestId,
      operation: request.operation,
      entityId,
      version: current.version as number,
      auditId,
      committedAt: receipt.committedAtIso as string,
      idempotentReplay: true,
      entity: current,
      linkedAbnormality: linkedAbnormality?.before ?? null,
    };
  }
  return {
    ok: true,
    requestId: request.requestId,
    operation: request.operation,
    entityId,
    version: resultVersion as number,
    auditId,
    committedAt: receipt.committedAtIso as string,
    idempotentReplay: true,
    entity: accepted,
    linkedAbnormality: acceptedLinked,
  };
}

function qualityReplayEvidenceMalformed(): never {
  throw new QualityMutationError(
    "data-loss",
    "Quality replay evidence is malformed or has drifted.",
    {reasonCode: "quality-replay-evidence-malformed"},
  );
}

function linkedAbnormalityReplayDrift(): never {
  throw new QualityMutationError(
    "data-loss",
    "Linked charge-abnormality replay evidence has drifted.",
    {reasonCode: "quality-replay-linked-abnormality-drift"},
  );
}

function qualityAuditSnapshot(value: unknown): UserAuthorityJsonMap {
  let snapshot: unknown = null;
  try {
    if (typeof value === "string") snapshot = JSON.parse(value);
  } catch (_) {
    snapshot = null;
  }
  if (snapshot == null || typeof snapshot !== "object" ||
      Array.isArray(snapshot)) {
    return qualityReplayEvidenceMalformed();
  }
  return snapshot as UserAuthorityJsonMap;
}

const WARNING_DATE_FIELDS = new Set([
  "createdAt",
  "updatedAt",
  "closureRequestedAt",
  "closedAt",
]);

const LINKED_DATE_FIELDS = new Set([
  "loggedAt",
  "updatedAt",
  "deletedAt",
]);

const CASE_IDENTITY_FIELDS = [
  "sourceType",
  "sourceId",
  "sourceChargeNo",
  "createdByUid",
  "createdByName",
];

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
function qualityRecordsMatch(
  expected: UserAuthorityJsonMap,
  actual: UserAuthorityJsonMap,
  dateFields: ReadonlySet<string>,
): boolean {
  const keys = new Set([...Object.keys(expected), ...Object.keys(actual)]);
  for (const key of keys) {
    if (key === "_globalPullServerUpdatedAt") continue;
    // An absent optional key and an explicit null describe the same absence.
    const left = expected[key] ?? null;
    const right = actual[key] ?? null;
    if (dateFields.has(key)) {
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

function auditWarningRecord(
  value: unknown,
  entityId: string,
): UserAuthorityJsonMap {
  try {
    return validateQualityWarningRecord(qualityAuditSnapshot(value), entityId);
  } catch (error) {
    if (error instanceof QualityMutationError) {
      return qualityReplayEvidenceMalformed();
    }
    throw error;
  }
}

// The lifecycle this command writes, so an audited decision cannot carry a
// disposition, reason or actor the request never asked for.
function commandedWarningLifecycle(args: {
  request: ParsedWarningRequest;
  accepted: UserAuthorityJsonMap;
  actorUid: string;
  actorName: unknown;
}): UserAuthorityJsonMap {
  const {request, accepted, actorUid, actorName} = args;
  const cleared: UserAuthorityJsonMap = {
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
  };
  switch (request.operation) {
  case "REQUEST_QUALITY_WARNING_CLOSURE":
  case "RECORD_QUALITY_CASE_RA_COMPLETED":
    return {
      ...cleared,
      status: "closureRequested",
      closureRequestReason: request.reason,
      closureRequestedAt: accepted.closureRequestedAt,
      closureRequestedByUid: actorUid,
      closureRequestedByName: actorName,
    };
  case "DECLARE_QUALITY_CASE_RA_REQUIRED":
  case "REOPEN_QUALITY_WARNING":
    return {...cleared, status: "open"};
  default:
    return {
      status: "closed",
      closedAt: accepted.closedAt,
      closedByUid: actorUid,
      closedByName: actorName,
      closureDisposition: request.disposition,
      linkedReannealingChargeNos: [...request.linkedReannealingChargeNos],
      decisionReason: request.reason,
    };
  }
}

// The decision this request committed, re-derived from the immutable audit and
// bound to the frozen command, so altered evidence cannot be returned as the
// original outcome.
function acceptedWarningFromAudit(args: {
  audit: UserAuthorityJsonMap;
  receipt: UserAuthorityJsonMap;
  current: UserAuthorityJsonMap;
  request: ParsedRequest;
  actorUid: string;
  entityId: string;
}): UserAuthorityJsonMap {
  const {audit, receipt, current, request, actorUid, entityId} = args;
  if (!("warningId" in request)) return qualityReplayEvidenceMalformed();
  const accepted = auditWarningRecord(audit.afterJson, entityId);
  const before = auditWarningRecord(audit.beforeJson, entityId);
  const committed = persistedInstantMillis(receipt.committedAtIso);
  const resultVersion = receipt.resultVersion;
  if (audit.operation !== request.operation ||
      audit.performedByUid !== actorUid ||
      audit.resultVersion !== resultVersion ||
      audit.expectedVersion !== request.expectedVersion ||
      before.version !== request.expectedVersion ||
      accepted.version !== resultVersion ||
      accepted.lastMutationId !== request.requestId ||
      accepted.updatedByUid !== actorUid ||
      accepted.updatedByName !== audit.performedByName ||
      !Number.isFinite(committed) ||
      !sameInstant(accepted.updatedAt, receipt.committedAtIso)) {
    return qualityReplayEvidenceMalformed();
  }
  for (const field of ["closureRequestedAt", "closedAt"]) {
    const value = accepted[field];
    if (value != null &&
        !sameInstant(value, receipt.committedAtIso) &&
        stableJson(value) !== stableJson(before[field])) {
      return qualityReplayEvidenceMalformed();
    }
  }
  const linkedWrites =
    request.operation !== "REQUEST_QUALITY_WARNING_CLOSURE" &&
    receipt.linkedAbnormalityId != null;
  const expected: UserAuthorityJsonMap = {
    ...before,
    ...canonicalNullableGaps(before, LEGACY_NULLABLE_WARNING_FIELDS),
    ...commandedWarningLifecycle({
      request,
      accepted,
      actorUid,
      actorName: audit.performedByName,
    }),
    sourceVersion: linkedWrites && before.sourceType === "abnormality" ?
      receipt.linkedAbnormalityVersion : before.sourceVersion,
    updatedAt: accepted.updatedAt,
    updatedByUid: actorUid,
    updatedByName: audit.performedByName,
    version: resultVersion,
    lastMutationId: request.requestId,
  };
  if (!qualityRecordsMatch(expected, accepted, WARNING_DATE_FIELDS)) {
    return qualityReplayEvidenceMalformed();
  }
  // Later decisions change lifecycle state, never which case this is.
  if (!sameInstant(accepted.createdAt, current.createdAt) ||
      CASE_IDENTITY_FIELDS.some((field) => accepted[field] !== current[field])) {
    return qualityReplayEvidenceMalformed();
  }
  return accepted;
}

// The linked-case state this command writes, so an audited snapshot cannot
// claim a re-annealing outcome the request never asked for.
function commandedLinkedCase(args: {
  request: ParsedWarningRequest;
  linked: UserAuthorityJsonMap;
  actorUid: string;
  receipt: UserAuthorityJsonMap;
}): boolean {
  const {request, linked, actorUid, receipt} = args;
  if (request.operation === "REQUEST_QUALITY_WARNING_CLOSURE") return true;
  if (linked.updatedByUid !== actorUid ||
      linked.isDeleted !== false ||
      !sameInstant(linked.updatedAt, receipt.committedAtIso)) {
    return false;
  }
  const charge = request.linkedReannealingChargeNos[0] ?? null;
  switch (request.operation) {
  case "DECLARE_QUALITY_CASE_RA_REQUIRED":
    return linked.reannealingStatus === "required" &&
      linked.reannealedToChargeNo == null;
  case "RECORD_QUALITY_CASE_RA_COMPLETED":
    return linked.reannealingStatus === "completed" &&
      linked.reannealedToChargeNo === charge;
  case "REOPEN_QUALITY_WARNING":
    return linked.reannealingStatus === "completed" ?
      linked.reannealedToChargeNo != null :
      linked.reannealingStatus === "pendingDecision" &&
        linked.reannealedToChargeNo == null;
  default:
    return request.disposition === "reannealingCompleted" ?
      linked.reannealingStatus === "completed" &&
        linked.reannealedToChargeNo === charge :
      linked.reannealingStatus === "notRequired" &&
        linked.reannealedToChargeNo == null;
  }
}

function acceptedLinkedAbnormality(args: {
  audit: UserAuthorityJsonMap;
  receipt: UserAuthorityJsonMap;
  request: ParsedRequest;
  actorUid: string;
  accepted: UserAuthorityJsonMap;
  linkedAbnormality: LinkedAbnormality | null;
  linkedUnchanged: boolean;
}): UserAuthorityJsonMap | null {
  const {audit, receipt, request, actorUid, accepted, linkedAbnormality} = args;
  if (linkedAbnormality == null || receipt.linkedAbnormalityId == null ||
      !("warningId" in request)) {
    return null;
  }
  if (typeof audit.linkedAbnormalityAfterJson !== "string") {
    // A decision audited before linked snapshots were recorded can be returned
    // whole only while the linked case still stands as that decision left it.
    if (args.linkedUnchanged) return linkedAbnormality.before;
    throw new QualityMutationError(
      "failed-precondition",
      "This decision was accepted earlier, and its linked charge abnormality " +
      "has changed since, so the original linked readback is unavailable. " +
      "Refresh the case and continue from its current state.",
      {
        reasonCode: "quality-replay-accepted-linked-history-unavailable",
        acceptanceEstablished: true,
        acceptedVersion: receipt.resultVersion,
        auditId: receipt.auditId,
        committedAt: receipt.committedAtIso,
      },
    );
  }
  let original: UserAuthorityJsonMap;
  try {
    original = validateLinkedAbnormality(
      qualityAuditSnapshot(audit.linkedAbnormalityAfterJson),
      linkedAbnormality.id,
      accepted,
      false,
    );
  } catch (error) {
    if (error instanceof QualityMutationError) {
      return qualityReplayEvidenceMalformed();
    }
    throw error;
  }
  if (original.version !== receipt.linkedAbnormalityVersion ||
      !commandedLinkedCase({request, linked: original, actorUid, receipt})) {
    return qualityReplayEvidenceMalformed();
  }
  return original;
}

export async function mutateQualityWithDb(args: {
  db: QualityMutationFirestoreLike;
  authUid: string | null;
  data: UserAuthorityJsonMap;
  now?: () => Date;
  timestampFromDate?: (date: Date) => unknown;
}): Promise<QualityMutationResult> {
  if (args.authUid == null || args.authUid.trim().length === 0) {
    throw new QualityMutationError(
      "unauthenticated",
      "Sign in before managing quality decisions.",
    );
  }
  const actorUid = args.authUid.trim();
  const request = parseQualityMutationRequest(args.data);
  const actorRef = args.db.collection("users").doc(actorUid);
  const collection = "warningId" in request ?
    "quality_warnings" : "quality_monitoring_requests";
  const entityId = targetIdentity(request);
  const targetRef = args.db.collection(collection).doc(entityId);
  const receiptRef = args.db
    .collection("quality_mutation_receipts")
    .doc(request.requestId);
  const auditId = `server_quality_${request.requestId}`;
  const auditRef = args.db.collection("audit_logs").doc(auditId);
  actorFromSnapshot(await actorRef.get(), actorUid, request.operation);
  const receiptProbe = await receiptRef.get();
  const monitoringBaseIdentity =
    (request.operation === "CREATE_QUALITY_MONITORING_REQUEST" || request.operation === "CORRECT_QUALITY_MONITORING_REQUEST") &&
    !receiptProbe.exists ?
      await resolveMonitoringBaseIdentity({db: args.db, request}) : null;

  const now = args.now ?? (() => new Date());
  const timestampFromDate = args.timestampFromDate ?? ((date: Date) => date);
  return args.db.runTransaction(async (transaction) => {
    const receiptSnapshot = await transaction.get(receiptRef);
    const actorSnapshot = await transaction.get(actorRef);
    const actor = actorFromSnapshot(actorSnapshot, actorUid, request.operation);
    const targetSnapshot = await transaction.get(targetRef);
    const auditSnapshot = await transaction.get(auditRef);
    const warningBefore =
      "warningId" in request && targetSnapshot.exists ?
        validateQualityWarningRecord(
          targetSnapshot.data() ?? {},
          request.warningId,
        ) : null;
    const linkedAbnormality = warningBefore == null ? null :
      await linkedAbnormalityForWarning({
        db: args.db,
        transaction,
        warning: warningBefore,
        // A replay may follow a legitimate later deletion of the source case.
        allowDeleted:
          (receiptSnapshot.exists ||
            request.operation === "REOPEN_QUALITY_WARNING") &&
          warningBefore.sourceType === "abnormality",
      });

    if (receiptSnapshot.exists) {
      return replayResult({
        request,
        actorUid,
        receipt: receiptSnapshot.data() ?? {},
        audit: auditSnapshot.exists ? auditSnapshot.data() ?? {} : null,
        target: targetSnapshot.exists ? targetSnapshot.data() ?? {} : null,
        linkedAbnormality,
        auditId,
      });
    }
    if (auditSnapshot.exists) {
      throw new QualityMutationError(
        "aborted",
        "The immutable quality audit identity is already occupied.",
        {reasonCode: "quality-audit-collision", auditId},
      );
    }

    let certifiedMonitoringBaseVersion: number | null = null;
    if (request.operation === "CREATE_QUALITY_MONITORING_REQUEST" || request.operation === "CORRECT_QUALITY_MONITORING_REQUEST") {
      if (monitoringBaseIdentity == null) {
        throw new QualityMutationError(
          "data-loss",
          "The governed Base identity could not be reconstructed.",
          {reasonCode: "quality-monitoring-base-identity-missing"},
        );
      }
      const classSnapshot = await transaction.get(
        args.db
          .collection("asset_classes")
          .doc(monitoringBaseIdentity.classId),
      );
      const assetSnapshot = await transaction.get(
        args.db
          .collection("asset_instances")
          .doc(monitoringBaseIdentity.instanceId),
      );
      certifiedMonitoringBaseVersion = certifyMonitoringBase({
        request,
        identity: monitoringBaseIdentity,
        classSnapshot,
        assetSnapshot,
      }).instanceVersion;
    }

    let before: UserAuthorityJsonMap | null = null;
    let after: UserAuthorityJsonMap;
    let resultVersion: number;
    let linkedAbnormalityAfter: UserAuthorityJsonMap | null = null;
    const committedDate = now();
    const committedAtIso = committedDate.toISOString();
    const committedAt = timestampFromDate(committedDate);

    if ("warningId" in request) {
      if (!targetSnapshot.exists) {
        throw new QualityMutationError(
          "not-found",
          "The quality warning was not found.",
          {reasonCode: "quality-warning-not-found"},
        );
      }
      before = warningBefore as UserAuthorityJsonMap;
      if (before.version !== request.expectedVersion) {
        throw new QualityMutationError(
          "aborted",
          "The quality warning changed before this decision was committed.",
          {
            reasonCode: "quality-warning-version-mismatch",
            currentVersion: before.version,
          },
        );
      }
      requireMonotonicQualityCommit(
        committedDate,
        before,
        "quality-warning",
      );
      resultVersion = request.expectedVersion + 1;
      after = {
        ...before,
        ...canonicalNullableGaps(before, LEGACY_NULLABLE_WARNING_FIELDS),
      };
      if (request.operation === "REQUEST_QUALITY_WARNING_CLOSURE") {
        if (before.status === "closed") {
          throw new QualityMutationError(
            "failed-precondition",
            "A closed quality warning cannot receive another closure request.",
            {reasonCode: "quality-warning-already-closed"},
          );
        }
        Object.assign(after, {
          status: "closureRequested",
          closureRequestReason: request.reason,
          closureRequestedAt: committedAt,
          closureRequestedByUid: actorUid,
          closureRequestedByName: actor.name,
          closedAt: null,
          closedByUid: null,
          closedByName: null,
          closureDisposition: null,
          linkedReannealingChargeNos: [],
          decisionReason: null,
        });
      } else if (request.operation === "DECLARE_QUALITY_CASE_RA_REQUIRED") {
        if (linkedAbnormality == null) {
          throw new QualityMutationError(
            "failed-precondition",
            "This legacy warning has no linked RA case.",
            {reasonCode: "quality-warning-ra-case-missing"},
          );
        }
        if (before.status === "closed") {
          throw new QualityMutationError(
            "failed-precondition",
            "Reopen the warning before declaring re-annealing required.",
            {reasonCode: "quality-warning-closed"},
          );
        }
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
      } else if (
        request.operation === "RECORD_QUALITY_CASE_RA_COMPLETED"
      ) {
        if (linkedAbnormality == null) {
          throw new QualityMutationError(
            "failed-precondition",
            "This legacy warning has no linked RA case.",
            {reasonCode: "quality-warning-ra-case-missing"},
          );
        }
        if (before.status === "closed") {
          throw new QualityMutationError(
            "failed-precondition",
            "Reopen the warning before recording re-annealing completion.",
            {reasonCode: "quality-warning-closed"},
          );
        }
        Object.assign(after, {
          status: "closureRequested",
          closureRequestReason: request.reason,
          closureRequestedAt: committedAt,
          closureRequestedByUid: actorUid,
          closureRequestedByName: actor.name,
          closedAt: null,
          closedByUid: null,
          closedByName: null,
          closureDisposition: null,
          linkedReannealingChargeNos: [],
          decisionReason: null,
        });
      } else if (request.operation === "CLOSE_QUALITY_WARNING") {
        if (before.status === "closed") {
          throw new QualityMutationError(
            "failed-precondition",
            "The quality warning is already closed.",
            {reasonCode: "quality-warning-already-closed"},
          );
        }
        Object.assign(after, {
          status: "closed",
          closedAt: committedAt,
          closedByUid: actorUid,
          closedByName: actor.name,
          closureDisposition: request.disposition,
          linkedReannealingChargeNos: request.linkedReannealingChargeNos,
          decisionReason: request.reason,
        });
      } else {
        if (before.status !== "closed") {
          throw new QualityMutationError(
            "failed-precondition",
            "Only a closed quality warning can be reopened.",
            {reasonCode: "quality-warning-not-closed"},
          );
        }
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
      if (linkedAbnormality != null &&
          request.operation !== "REQUEST_QUALITY_WARNING_CLOSURE") {
        requireMonotonicQualityCommit(
          committedDate,
          linkedAbnormality.before,
          "charge-quality-abnormality",
        );
        const linkedVersion = linkedAbnormality.before.version as number;
        const nextLinkedVersion = linkedVersion + 1;
        if (!Number.isSafeInteger(nextLinkedVersion)) {
          throw new QualityMutationError(
            "failed-precondition",
            "The linked charge-abnormality version cannot advance safely.",
            {reasonCode: "charge-quality-abnormality-version-overflow"},
          );
        }
        let reannealingStatus: string;
        let reannealedToChargeNo: number | null = null;
        if (request.operation === "DECLARE_QUALITY_CASE_RA_REQUIRED") {
          if (linkedAbnormality.before.reannealingStatus === "completed") {
            throw new QualityMutationError(
              "failed-precondition",
              "A recorded RA-completed state cannot be returned to RA required. Correct the abnormality first.",
              {reasonCode: "charge-quality-ra-already-completed"},
            );
          }
          reannealingStatus = "required";
        } else if (
          request.operation === "RECORD_QUALITY_CASE_RA_COMPLETED"
        ) {
          if (linkedAbnormality.before.reannealingStatus !== "required") {
            throw new QualityMutationError(
              "failed-precondition",
              "Re-annealing must be required before Operations records completion.",
              {reasonCode: "charge-quality-ra-not-required"},
            );
          }
          reannealingStatus = "completed";
          reannealedToChargeNo = request.linkedReannealingChargeNos[0];
        } else if (request.operation === "REOPEN_QUALITY_WARNING") {
          const completedRa =
            linkedAbnormality.before.reannealingStatus === "completed";
          reannealingStatus = completedRa ? "completed" : "pendingDecision";
          reannealedToChargeNo = completedRa ?
            linkedAbnormality.before.reannealedToChargeNo as number : null;
        } else if (request.disposition === "reannealingCompleted") {
          const priorRaStatus = linkedAbnormality.before.reannealingStatus;
          if (priorRaStatus !== "required" && priorRaStatus !== "completed") {
            throw new QualityMutationError(
              "failed-precondition",
              "Re-annealing completion requires an operational RA-required or RA-completed state.",
              {reasonCode: "charge-quality-ra-not-required"},
            );
          }
          if (request.linkedReannealingChargeNos.length !== 1) {
            throw new QualityMutationError(
              "failed-precondition",
              "A connected RA case requires exactly one resulting charge.",
              {reasonCode: "charge-quality-ra-charge-count-invalid"},
            );
          }
          reannealingStatus = "completed";
          reannealedToChargeNo = request.linkedReannealingChargeNos[0];
          if (priorRaStatus === "completed" &&
              linkedAbnormality.before.reannealedToChargeNo !==
                reannealedToChargeNo) {
            throw new QualityMutationError(
              "failed-precondition",
              "The adjudicated RA charge must match the charge already recorded by Operations.",
              {reasonCode: "charge-quality-ra-charge-mismatch"},
            );
          }
        } else {
          if (linkedAbnormality.before.reannealingStatus === "completed") {
            throw new QualityMutationError(
              "failed-precondition",
              "A recorded RA-completed state cannot be replaced during warning closure. Correct the abnormality first.",
              {reasonCode: "charge-quality-ra-completion-conflict"},
            );
          }
          if (linkedAbnormality.before.reannealingStatus === "required") {
            throw new QualityMutationError(
              "failed-precondition",
              "A required re-annealing case can close only after its resulting charge is recorded. Correct the abnormality first if the RA decision was wrong.",
              {reasonCode: "charge-quality-ra-required"},
            );
          }
          reannealingStatus = "notRequired";
        }
        if (reannealedToChargeNo === linkedAbnormality.before.sourceChargeNo) {
          throw new QualityMutationError(
            "failed-precondition",
            "The re-annealed charge must differ from the source charge.",
            {reasonCode: "reannealed-charge-matches-source"},
          );
        }
        linkedAbnormalityAfter = {
          ...linkedAbnormality.before,
          ...canonicalNullableGaps(
            linkedAbnormality.before,
            LEGACY_NULLABLE_CASE_FIELDS,
          ),
          reannealingStatus,
          reannealedToChargeNo,
          ...(request.operation === "REOPEN_QUALITY_WARNING" ? {
            isDeleted: false,
            deletedAt: null,
            deletedByUid: null,
            deletedByName: null,
            deleteReason: null,
          } : {}),
          updatedAt: committedAtIso,
          updatedByUid: actorUid,
          updatedByName: actor.name,
          version: nextLinkedVersion,
        };
        if (before.sourceType === "abnormality") {
          after.sourceVersion = nextLinkedVersion;
        }
      }
    } else if (request.operation === "CREATE_QUALITY_MONITORING_REQUEST") {
      if (targetSnapshot.exists) {
        throw new QualityMutationError(
          "already-exists",
          "The monitoring request already exists.",
          {reasonCode: "quality-monitoring-already-exists"},
        );
      }
      resultVersion = 1;
      if (monitoringBaseIdentity == null ||
          certifiedMonitoringBaseVersion == null) {
        throw new QualityMutationError(
          "data-loss",
          "The governed Base certification is unavailable.",
          {reasonCode: "quality-monitoring-base-certification-missing"},
        );
      }
      after = {
        schemaVersion: 3,
        requestId: request.monitoringRequestId,
        baseNumber: request.baseNumber,
        baseAssetClassId: monitoringBaseIdentity.classId,
        baseAssetInstanceId: monitoringBaseIdentity.instanceId,
        baseAssetInstanceVersion: certifiedMonitoringBaseVersion,
        grade: request.grade,
        cycleReference: request.cycleReference,
        chargeNumbers: request.chargeNumbers,
        reason: request.reason,
        status: "active",
        visibilityState: "active",
        visibleUntil: null,
        archivedAt: null,
        createdAt: committedAt,
        createdByUid: actorUid,
        createdByName: actor.name,
        closedAt: null,
        closedByUid: null,
        closedByName: null,
        closeReason: null,
        updatedAt: committedAt,
        updatedByUid: actorUid,
        updatedByName: actor.name,
        version: resultVersion,
        lastMutationId: request.requestId,
      };
    } else {
      if (!targetSnapshot.exists) {
        throw new QualityMutationError(
          "not-found",
          "The monitoring request was not found.",
          {reasonCode: "quality-monitoring-not-found"},
        );
      }
      before = validateQualityMonitoringRecord(
        targetSnapshot.data() ?? {},
        request.monitoringRequestId,
      );
      if (before.version !== request.expectedVersion) {
        throw new QualityMutationError(
          "aborted",
          "The monitoring request changed before closure.",
          {
            reasonCode: "quality-monitoring-version-mismatch",
            currentVersion: before.version,
          },
        );
      }
      if (before.status !== "active") {
        throw new QualityMutationError(
          "failed-precondition",
          "Only an active monitoring request can be closed.",
          {reasonCode: "quality-monitoring-not-active"},
        );
      }
      requireMonotonicQualityCommit(
        committedDate,
        before,
        "quality-monitoring",
      );
      resultVersion = request.expectedVersion + 1;
      const correcting = request.operation === "CORRECT_QUALITY_MONITORING_REQUEST";
      const cancelling = request.operation === "CANCEL_QUALITY_MONITORING_REQUEST";
      if (correcting && (monitoringBaseIdentity == null || certifiedMonitoringBaseVersion == null)) {
        throw new QualityMutationError("data-loss", "Reviewed Base certification is unavailable.");
      }
      after = correcting ? {
        ...before, schemaVersion: 4,
        baseNumber: request.baseNumber,
        baseAssetClassId: monitoringBaseIdentity!.classId,
        baseAssetInstanceId: monitoringBaseIdentity!.instanceId,
        baseAssetInstanceVersion: certifiedMonitoringBaseVersion,
        grade: request.grade, cycleReference: request.cycleReference, chargeNumbers: request.chargeNumbers,
        monitoringDisposition: null,
        originalMonitoringContext: before.originalMonitoringContext ?? monitoringContext(before),
      } : {
        ...before,
        schemaVersion: cancelling ? 4 : before.schemaVersion === 1 ? 2 : before.schemaVersion,
        ...(cancelling || before.schemaVersion === 4 ? {
          monitoringDisposition: cancelling ? "cancelled" : "completed",
          originalMonitoringContext: before.originalMonitoringContext ?? monitoringContext(before),
        } : {}),
        status: "closed",
        visibilityState: "recent",
        visibleUntil: timestampFromDate(new Date(
          committedDate.valueOf() + QUALITY_MONITORING_OPERATIONAL_RETENTION_MS,
        )),
        archivedAt: null,
        closedAt: committedAt,
        closedByUid: actorUid,
        closedByName: actor.name,
        closeReason: request.reason,
      };
    }

    if (!Number.isSafeInteger(resultVersion)) {
      throw new QualityMutationError(
        "failed-precondition",
        "The quality record version cannot advance safely.",
        {reasonCode: "quality-version-overflow"},
      );
    }
    Object.assign(after, {
      updatedAt: committedAt,
      updatedByUid: actorUid,
      updatedByName: actor.name,
      version: resultVersion,
      lastMutationId: request.requestId,
    });
    if ("warningId" in request) {
      after = validateQualityWarningRecord(after, request.warningId);
      if (linkedAbnormality != null && linkedAbnormalityAfter != null) {
        linkedAbnormalityAfter = validateLinkedAbnormality(
          linkedAbnormalityAfter,
          linkedAbnormality.id,
          after,
          false,
        );
      }
    } else {
      after = validateQualityMonitoringRecord(
        after,
        request.monitoringRequestId,
      );
    }
    transaction.set(targetRef, after);
    if (linkedAbnormality != null && linkedAbnormalityAfter != null) {
      transaction.set(linkedAbnormality.ref, linkedAbnormalityAfter);
    }
    const auditRecord: UserAuthorityJsonMap = {
      schemaVersion: 1,
      eventType: "qualityMutation",
      entityType: "warningId" in request ?
        "quality_warning" : "quality_monitoring_request",
      entityId,
      action: qualityAuditActionForOperation(request.operation),
      severity: "high",
      performedByUid: actorUid,
      performedByName: actor.name,
      timestamp: committedAt,
      reason: "other",
      reasonNotes: request.reason,
      summary: `Quality command ${request.operation}`,
      beforeJson: before == null ? null : JSON.stringify(before),
      afterJson: JSON.stringify(after),
      requestId: request.requestId,
      operation: request.operation,
      expectedVersion: request.expectedVersion,
      resultVersion,
      linkedAbnormalityId: linkedAbnormality?.id ?? null,
      linkedAbnormalityBeforeVersion:
        linkedAbnormality?.before.version ?? null,
      linkedAbnormalityResultVersion:
        linkedAbnormalityAfter?.version ?? linkedAbnormality?.before.version ?? null,
    };
    if ("warningId" in request) {
      // Lets a later retry return the linked case exactly as this decision
      // left it, even after further work has changed the live case.
      auditRecord.linkedAbnormalityAfterJson = linkedAbnormality == null ? null :
        JSON.stringify(linkedAbnormalityAfter ?? linkedAbnormality.before);
    }
    const creatingMonitoring = request.operation === "CREATE_QUALITY_MONITORING_REQUEST";
    const storedFingerprint = creatingMonitoring ? monitoringCreationFingerprint(request) : request.fingerprint;
    if (creatingMonitoring) Object.assign(auditRecord, {
      creationEvidenceVersion: 2, payloadFingerprint: storedFingerprint,
    });
    transaction.set(auditRef, auditRecord);
    transaction.set(receiptRef, {
      schemaVersion: 1,
      requestId: request.requestId,
      actorUid,
      entityId,
      operation: request.operation,
      payloadFingerprint: storedFingerprint,
      ...(creatingMonitoring ? {creationEvidenceVersion: 2,
        creationAuditSha256: auditEvidenceDigest(auditRecord)} : {}),
      // Binds the accepted evidence, so a later retry detects any change to it.
      ...(!creatingMonitoring ? {acceptedEvidenceVersion: 2,
        acceptedAuditSha256: auditEvidenceDigest(auditRecord)} : {}),
      expectedVersion: request.expectedVersion,
      resultVersion,
      linkedAbnormalityId: linkedAbnormality?.id ?? null,
      linkedAbnormalityVersion:
        linkedAbnormalityAfter?.version ?? linkedAbnormality?.before.version ?? null,
      auditId,
      committedAt,
      committedAtIso,
    });
    return {
      ok: true,
      requestId: request.requestId,
      operation: request.operation,
      entityId,
      version: resultVersion,
      auditId,
      committedAt: committedAtIso,
      idempotentReplay: false,
      entity: after,
      linkedAbnormality:
        linkedAbnormalityAfter ?? linkedAbnormality?.before ?? null,
    };
  });
}
