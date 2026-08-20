import {createHash} from "crypto";
import {isFiveDigitChargeNumber} from "./chargeNumber";

import {stableJson} from "./stableJson";
import {
  canonicalApprovedUserAuthority,
  UserAuthorityJsonMap,
} from "./userAuthority";

export type QualityMutationOperation =
  | "REQUEST_QUALITY_WARNING_CLOSURE"
  | "CLOSE_QUALITY_WARNING"
  | "REOPEN_QUALITY_WARNING"
  | "CREATE_QUALITY_MONITORING_REQUEST"
  | "CLOSE_QUALITY_MONITORING_REQUEST";

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
  "CLOSE_QUALITY_WARNING",
  "REOPEN_QUALITY_WARNING",
  "CREATE_QUALITY_MONITORING_REQUEST",
  "CLOSE_QUALITY_MONITORING_REQUEST",
]);
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
  if (reason.length < 8) invalid("reason", "must contain at least 8 characters");
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

function malformed(entity: string, field?: string): never {
  throw new QualityMutationError(
    "failed-precondition",
    `The persisted ${entity} is malformed.`,
    {reasonCode: `${entity}-malformed`, ...(field == null ? {} : {field})},
  );
}

function validateWarning(
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

function validateMonitoring(
  data: UserAuthorityJsonMap,
  requestId: string,
): UserAuthorityJsonMap {
  for (const key of Object.keys(data)) {
    if (!MONITORING_FIELDS.has(key)) malformed("quality-monitoring", key);
  }
  for (const field of [...MONITORING_FIELDS].filter((value) =>
    value !== "_globalPullServerUpdatedAt")) {
    if (!Object.prototype.hasOwnProperty.call(data, field)) {
      malformed("quality-monitoring", field);
    }
  }
  if (data.schemaVersion !== 1 || data.requestId !== requestId) {
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
  const closureEvidence = [
    optionalExistingDate(data.closedAt, "closedAt", "quality-monitoring"),
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
  return {...data};
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
  auditId: string;
}): QualityMutationResult {
  const {request, actorUid, receipt, audit, target, auditId} = args;
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
    validateWarning(target, entityId) : validateMonitoring(target, entityId);
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

    if (receiptSnapshot.exists) {
      return replayResult({
        request,
        actorUid,
        receipt: receiptSnapshot.data() ?? {},
        audit: auditSnapshot.exists ? auditSnapshot.data() ?? {} : null,
        target: targetSnapshot.exists ? targetSnapshot.data() ?? {} : null,
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
      before = validateWarning(targetSnapshot.data() ?? {}, request.warningId);
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
        schemaVersion: 1,
        requestId: request.monitoringRequestId,
        baseNumber: request.baseNumber,
        grade: request.grade,
        cycleReference: request.cycleReference,
        chargeNumbers: request.chargeNumbers,
        reason: request.reason,
        status: "active",
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
      before = validateMonitoring(
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
        status: "closed",
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
    transaction.set(auditRef, {
      schemaVersion: 1,
      eventType: "qualityMutation",
      entityType: "warningId" in request ?
        "quality_warning" : "quality_monitoring_request",
      entityId,
      action: request.operation,
      severity: "high",
      performedByUid: actorUid,
      performedByName: actor.name,
      timestamp: committedAt,
      reason: "qualityAssurance",
      reasonNotes: request.reason,
      summary: `Quality command ${request.operation}`,
      beforeJson: before == null ? null : JSON.stringify(before),
      afterJson: JSON.stringify(after),
      requestId: request.requestId,
      operation: request.operation,
      expectedVersion: request.expectedVersion,
      resultVersion,
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
