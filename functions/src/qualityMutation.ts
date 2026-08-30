import {createHash} from "crypto";
import {isFiveDigitChargeNumber} from "./chargeNumber";

import {stableJson} from "./stableJson";
import {
  canonicalApprovedUserAuthority,
  UserAuthorityJsonMap,
} from "./userAuthority";

export type QualityMutationOperation =
  | "REQUEST_QUALITY_WARNING_CLOSURE"
  | "DECLARE_QUALITY_CASE_RA_REQUIRED"
  | "CLOSE_QUALITY_WARNING"
  | "REOPEN_QUALITY_WARNING"
  | "CREATE_QUALITY_MONITORING_REQUEST"
  | "CLOSE_QUALITY_MONITORING_REQUEST";

export function qualityAuditActionForOperation(
  operation: QualityMutationOperation,
): "create" | "update" | "resolve" | "reopen" {
  switch (operation) {
  case "REQUEST_QUALITY_WARNING_CLOSURE":
  case "DECLARE_QUALITY_CASE_RA_REQUIRED":
    return "update";
  case "CLOSE_QUALITY_WARNING":
  case "CLOSE_QUALITY_MONITORING_REQUEST":
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
  };
  runTransaction: <T>(fn: (transaction: TransactionLike) => Promise<T>) =>
    Promise<T>;
};

type WarningOperation = Exclude<
  QualityMutationOperation,
  "CREATE_QUALITY_MONITORING_REQUEST" |
  "CLOSE_QUALITY_MONITORING_REQUEST"
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
    | "CLOSE_QUALITY_MONITORING_REQUEST";
  monitoringRequestId: string;
  expectedVersion: number;
  reason: string;
  baseNumber: number | null;
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
}

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const OPERATIONS = new Set<QualityMutationOperation>([
  "REQUEST_QUALITY_WARNING_CLOSURE",
  "DECLARE_QUALITY_CASE_RA_REQUIRED",
  "CLOSE_QUALITY_WARNING",
  "REOPEN_QUALITY_WARNING",
  "CREATE_QUALITY_MONITORING_REQUEST",
  "CLOSE_QUALITY_MONITORING_REQUEST",
]);
export const QUALITY_MONITORING_OPERATIONAL_RETENTION_MS =
  7 * 24 * 60 * 60 * 1000;
const REQUEST_ROLES = new Set([
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
const MONITORING_FIELDS = new Set([
  "schemaVersion",
  "requestId",
  "baseNumber",
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
    REQUEST_ROLES : DECISION_ROLES;
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
  const reason = requiredString(raw.reason, "reason", 1000);
  const expectedVersion = nonNegativeInteger(
    raw.expectedVersion,
    "expectedVersion",
  );

  if (operation.includes("MONITORING_REQUEST")) {
    const monitoringOperation = operation as ParsedMonitoringRequest["operation"];
    const create = operation === "CREATE_QUALITY_MONITORING_REQUEST";
    const allowed = new Set([
      "requestId",
      "operation",
      "monitoringRequestId",
      "expectedVersion",
      "reason",
      ...(create ? [
        "baseNumber",
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
    const canonical = {
      requestId,
      operation: monitoringOperation,
      monitoringRequestId,
      expectedVersion,
      reason,
      baseNumber: create ? positiveInteger(raw.baseNumber, "baseNumber") : null,
      grade: create ? requiredString(raw.grade, "grade", 120) : null,
      cycleReference: create ?
        requiredString(raw.cycleReference, "cycleReference", 200) : null,
      chargeNumbers: create ?
        positiveIntegerList(raw.chargeNumbers, "chargeNumbers", 50) : [],
    };
    return {...canonical, fingerprint: requestFingerprint(canonical)};
  }

  const close = operation === "CLOSE_QUALITY_WARNING";
  const allowed = new Set([
    "requestId",
    "operation",
    "warningId",
    "expectedVersion",
    "reason",
    ...(close ? ["disposition", "linkedReannealingChargeNos"] : []),
  ]);
  for (const key of Object.keys(raw)) if (!allowed.has(key)) invalid(key, "is unsupported");
  const disposition = close ? requiredString(raw.disposition, "disposition", 64) : null;
  if (disposition != null && !DISPOSITIONS.has(disposition)) {
    invalid("disposition", "is unsupported");
  }
  const linkedReannealingChargeNos = close ?
    positiveIntegerList(
      raw.linkedReannealingChargeNos,
      "linkedReannealingChargeNos",
      20,
    ) : [];
  if (disposition === "reannealingCompleted" &&
      linkedReannealingChargeNos.length === 0) {
    invalid(
      "linkedReannealingChargeNos",
      "must contain at least one RA charge for re-annealing closure",
    );
  }
  if (disposition !== "reannealingCompleted" &&
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
  if (value instanceof Date) return !Number.isNaN(value.valueOf());
  if (typeof value === "string") return !Number.isNaN(Date.parse(value));
  if (value == null || typeof value !== "object") return false;
  const timestamp = value as {
    toDate?: unknown;
    seconds?: unknown;
    nanoseconds?: unknown;
  };
  return typeof timestamp.toDate === "function" ||
    (Number.isSafeInteger(timestamp.seconds) &&
      Number.isSafeInteger(timestamp.nanoseconds));
}

function dateMillis(value: unknown, field: string, entity: string): number {
  if (value instanceof Date) return value.valueOf();
  if (typeof value === "string") return Date.parse(value);
  if (value == null || typeof value !== "object") malformed(entity, field);
  const timestamp = value as {
    toDate?: () => Date;
    seconds?: unknown;
    nanoseconds?: unknown;
  };
  if (typeof timestamp.toDate === "function") {
    return timestamp.toDate().valueOf();
  }
  if (Number.isSafeInteger(timestamp.seconds) &&
      Number.isSafeInteger(timestamp.nanoseconds)) {
    return (timestamp.seconds as number) * 1000 +
      (timestamp.nanoseconds as number) / 1_000_000;
  }
  return malformed(entity, field);
}

function malformed(entity: string, field?: string): never {
  throw new QualityMutationError(
    "failed-precondition",
    `The persisted ${entity} is malformed.`,
    {reasonCode: `${entity}-malformed`, ...(field == null ? {} : {field})},
  );
}

export function validateQualityWarningRecord(
  data: UserAuthorityJsonMap,
  warningId: string,
): UserAuthorityJsonMap {
  for (const key of Object.keys(data)) {
    if (!WARNING_FIELDS.has(key)) malformed("quality-warning", key);
  }
  for (const field of [...WARNING_FIELDS].filter((value) =>
    value !== "_globalPullServerUpdatedAt" && value !== "lastMutationId")) {
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
      data.affectedAssets.length === 0 ||
      data.affectedAssets.length > 50) {
    malformed("quality-warning", "affectedAssets");
  }
  data.affectedAssets.forEach((raw, index) => {
    if (raw == null || typeof raw !== "object" || Array.isArray(raw)) {
      malformed("quality-warning", `affectedAssets[${index}]`);
    }
    const asset = raw as UserAuthorityJsonMap;
    if (Object.keys(asset).length !== 2 ||
        !Object.prototype.hasOwnProperty.call(asset, "assetType") ||
        !Object.prototype.hasOwnProperty.call(asset, "assetNumber")) {
      malformed("quality-warning", `affectedAssets[${index}]`);
    }
    requiredExistingString(
      asset.assetType,
      `affectedAssets[${index}].assetType`,
      "quality-warning",
    );
    positiveExistingInteger(
      asset.assetNumber,
      `affectedAssets[${index}].assetNumber`,
      "quality-warning",
    );
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
  if (new Set(charges).size !== charges.length) {
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
    value !== "_globalPullServerUpdatedAt")) {
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
  positiveExistingInteger(
    data.version,
    "version",
    "charge-quality-abnormality",
  );
  requiredExistingString(
    data.abnormalityTypeId,
    "abnormalityTypeId",
    "charge-quality-abnormality",
  );
  requiredExistingString(
    data.observedReason,
    "observedReason",
    "charge-quality-abnormality",
  );
  requiredExistingString(
    data.loggedByUid,
    "loggedByUid",
    "charge-quality-abnormality",
  );
  requiredExistingString(
    data.updatedByUid,
    "updatedByUid",
    "charge-quality-abnormality",
  );
  if (!validDate(data.loggedAt) || !validDate(data.updatedAt) ||
      !REANNEALING_STATUSES.has(data.reannealingStatus as string)) {
    malformed("charge-quality-abnormality", "reannealingStatus");
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
    );
    requiredExistingString(
      data.deletedByName,
      "deletedByName",
      "charge-quality-abnormality",
    );
    requiredExistingString(
      data.deleteReason,
      "deleteReason",
      "charge-quality-abnormality",
    );
  } else if (data.deletedAt != null || data.deletedByUid != null ||
      data.deletedByName != null || data.deleteReason != null) {
    malformed("charge-quality-abnormality", "isDeleted");
  }
  const expectedTicketId = warning.sourceType === "issue" ?
    warning.sourceId : null;
  if (data.linkedTicketFirestoreId !== expectedTicketId) {
    malformed("charge-quality-abnormality", "linkedTicketFirestoreId");
  }
  return {...data};
}

type LinkedAbnormality = {
  readonly id: string;
  readonly ref: DocumentRefLike;
  readonly before: UserAuthorityJsonMap;
};

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
    const ticketSnapshot = await transaction.get(
      db.collection("maintenance_records").doc(ticketId),
    );
    if (!ticketSnapshot.exists) return null;
    const ticket = ticketSnapshot.data() ?? {};
    const linkValues = [
      ticket.qualityAbnormalityId,
      ticket.qualityWarningId,
      ticket.chargeQualityCaseId,
    ];
    if (linkValues.every((value) => value == null)) return null;
    const expectedAbnormalityId = `issue_quality_${ticketId}`;
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
    if (!MONITORING_FIELDS.has(key)) malformed("quality-monitoring", key);
  }
  const schemaVersion = data.schemaVersion;
  if (schemaVersion !== 1 && schemaVersion !== 2) {
    malformed("quality-monitoring", "schemaVersion");
  }
  const visibilityFieldCount = [...MONITORING_VISIBILITY_FIELDS]
    .filter((field) => Object.prototype.hasOwnProperty.call(data, field)).length;
  if ((schemaVersion === 1 && visibilityFieldCount !== 0) ||
      (schemaVersion === 2 &&
        visibilityFieldCount !== MONITORING_VISIBILITY_FIELDS.size)) {
    malformed("quality-monitoring", "visibilityState");
  }
  for (const field of [...MONITORING_FIELDS].filter((value) =>
    value !== "_globalPullServerUpdatedAt")) {
    if (schemaVersion === 1 && MONITORING_VISIBILITY_FIELDS.has(field)) {
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
  if (new Set(charges).size !== charges.length) {
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
  return {...data, visibilityState, visibleUntil, archivedAt};
}

function requiredExistingString(
  value: unknown,
  field: string,
  entity: string,
): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    malformed(entity, field);
  }
  return (value as string).trim();
}

function optionalExistingString(
  value: unknown,
  field: string,
  entity: string,
): string | null {
  return value == null ? null : requiredExistingString(value, field, entity);
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
  if (receipt.payloadFingerprint !== request.fingerprint ||
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
  const hasLinkedEvidence = Object.prototype.hasOwnProperty.call(
    receipt,
    "linkedAbnormalityId",
  ) || Object.prototype.hasOwnProperty.call(
    receipt,
    "linkedAbnormalityVersion",
  );
  if (hasLinkedEvidence &&
      (receipt.linkedAbnormalityId !== (linkedAbnormality?.id ?? null) ||
        receipt.linkedAbnormalityVersion !==
          (linkedAbnormality?.before.version ?? null))) {
    throw new QualityMutationError(
      "data-loss",
      "Linked charge-abnormality replay evidence has drifted.",
      {reasonCode: "quality-replay-linked-abnormality-drift"},
    );
  }
  if (receipt.resultVersion !== current.version ||
      current.lastMutationId !== request.requestId ||
      receipt.schemaVersion !== 1 ||
      receipt.auditId !== auditId ||
      audit.schemaVersion !== 1 ||
      audit.eventType !== "qualityMutation" ||
      audit.requestId !== request.requestId ||
      audit.entityId !== entityId) {
    throw new QualityMutationError(
      "data-loss",
      "Quality replay evidence is malformed or has drifted.",
      {reasonCode: "quality-replay-evidence-malformed"},
    );
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
  };
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
        allowDeleted:
          request.operation === "REOPEN_QUALITY_WARNING" &&
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
      resultVersion = request.expectedVersion + 1;
      after = {...before};
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
          reannealingStatus = "required";
        } else if (request.operation === "REOPEN_QUALITY_WARNING") {
          reannealingStatus = "pendingDecision";
        } else if (request.disposition === "reannealingCompleted") {
          if (linkedAbnormality.before.reannealingStatus !== "required") {
            throw new QualityMutationError(
              "failed-precondition",
              "Re-annealing completion requires a prior RA-required decision.",
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
        } else {
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
      after = {
        schemaVersion: 2,
        requestId: request.monitoringRequestId,
        baseNumber: request.baseNumber,
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
      resultVersion = request.expectedVersion + 1;
      after = {
        ...before,
        schemaVersion: 2,
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
    transaction.set(targetRef, after);
    if (linkedAbnormality != null && linkedAbnormalityAfter != null) {
      transaction.set(linkedAbnormality.ref, linkedAbnormalityAfter);
    }
    transaction.set(auditRef, {
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
    });
    transaction.set(receiptRef, {
      schemaVersion: 1,
      requestId: request.requestId,
      actorUid,
      entityId,
      operation: request.operation,
      payloadFingerprint: request.fingerprint,
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
    };
  });
}
