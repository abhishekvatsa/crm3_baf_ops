import {createHash} from "crypto";
import {isFiveDigitChargeNumber} from "./chargeNumber";
import {validateQualityWarningRecord} from "./qualityMutation";

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
  | "aborted"
  | "data-loss"
  | "internal";

export type ChargeAbnormalityMutationOperation =
  | "UPDATE"
  | "SOFT_DELETE";

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
};

type ParsedChargeAbnormalityUpdate = {
  readonly abnormalityTypeId: string;
  readonly severity: string;
  readonly affectedAssets: ReadonlyArray<AffectedAsset>;
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
  "UPDATE",
  "SOFT_DELETE",
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
const UPDATE_REQUEST_FIELDS = new Set([
  ...COMMON_REQUEST_FIELDS,
  "abnormalityTypeId",
  "severity",
  "affectedAssets",
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
  (field) => field !== "_globalPullServerUpdatedAt",
);
const MAX_AFFECTED_ASSETS = 50;

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

function parseAffectedAssets(value: unknown): ReadonlyArray<AffectedAsset> {
  if (!Array.isArray(value) || value.length > MAX_AFFECTED_ASSETS) {
    return invalidField(
      "affectedAssets",
      `affectedAssets must be a list of at most ${MAX_AFFECTED_ASSETS} items.`,
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
    if (
      keys.length !== 2 ||
      !keys.includes("assetType") ||
      !keys.includes("assetNumber")
    ) {
      return invalidField(
        `affectedAssets[${index}]`,
        "Each affected asset must contain only assetType and assetNumber.",
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
    const identity = `${assetType}:${assetNumber}`;
    if (seen.has(identity)) {
      return invalidField(
        "affectedAssets",
        "affectedAssets must not contain duplicates.",
        "duplicate-affected-asset",
      );
    }
    seen.add(identity);
    return {assetType, assetNumber};
  });
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

  return {
    abnormalityTypeId: cleanDocumentId(
      raw.abnormalityTypeId,
      "abnormalityTypeId",
    ),
    severity: enumValue(raw.severity, "severity", SEVERITIES),
    affectedAssets: parseAffectedAssets(raw.affectedAssets),
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
    operation === "UPDATE" ? UPDATE_REQUEST_FIELDS : COMMON_REQUEST_FIELDS;
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
  const expectedVersion = positiveSafeInteger(
    raw.expectedVersion,
    "expectedVersion",
  );
  const reason = cleanRequiredString(raw.reason, "reason", 500);
  if (reason.length < 8) {
    return invalidField(
      "reason",
      "reason must contain at least 8 characters.",
      "abnormality-reason-too-short",
    );
  }
  const update = operation === "UPDATE" ? parseUpdate(raw) : null;
  const canonicalPayload = {
    requestId,
    abnormalityId,
    operation,
    expectedVersion,
    reason,
    ...(update ?? {}),
  };
  return {
    requestId,
    abnormalityId,
    operation,
    expectedVersion,
    reason,
    update,
    payloadFingerprint: fingerprint(canonicalPayload),
  };
}

export function userCanMutateChargeAbnormality(
  data: UserAuthorityJsonMap | null | undefined,
): boolean {
  const authority = canonicalApprovedUserAuthority(data);
  return authority != null && authority.roles.has("admin");
}

function requireActor(
  snapshot: ChargeAbnormalityMutationDocumentSnapshotLike,
  actorUid: string,
): {readonly name: string} {
  const data = snapshot.exists ? snapshot.data() ?? {} : {};
  if (!userCanMutateChargeAbnormality(data)) {
    throw new ChargeAbnormalityMutationError(
      "permission-denied",
      "Approved Admin authority is required.",
      {reasonCode: "approved-admin-required"},
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
    !Number.isNaN(Date.parse(value));
}

function validServerTimestamp(value: unknown): boolean {
  if (value instanceof Date) return !Number.isNaN(value.valueOf());
  if (validIsoTimestamp(value)) return true;
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

function malformedExisting(message: string, field?: string): never {
  throw new ChargeAbnormalityMutationError(
    "failed-precondition",
    message,
    {
      reasonCode: "abnormality-record-malformed",
      ...(field == null ? {} : {field}),
    },
  );
}

function validateExistingAbnormality(
  data: UserAuthorityJsonMap,
  abnormalityId: string,
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
  existingAssets(data.affectedAssets);
  requiredExistingString(data.observedReason, "observedReason", 2000);
  requiredExistingString(data.loggedByUid, "loggedByUid", 512);
  requiredExistingString(data.updatedByUid, "updatedByUid", 512);
  if (!validIsoTimestamp(data.loggedAt)) {
    return malformedExisting(
      "The charge-abnormality loggedAt value is malformed.",
      "loggedAt",
    );
  }
  if (!validIsoTimestamp(data.updatedAt)) {
    return malformedExisting(
      "The charge-abnormality updatedAt value is malformed.",
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

function existingAssets(value: unknown): void {
  try {
    parseAffectedAssets(value);
  } catch (error) {
    if (error instanceof ChargeAbnormalityMutationError) {
      malformedExisting(
        "The charge-abnormality affectedAssets value is malformed.",
        "affectedAssets",
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
    !validIsoTimestamp(data.deletedAt)
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
      (data.reannealedToChargeNo as number) <= 0
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
      !validIsoTimestamp(data.deletedAt) ||
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
  const sourceChanged = linkedTicketId == null && [
    "abnormalityTypeTitle",
    "severity",
    "affectedAssets",
    "component",
    "observedReason",
  ].some((field) => JSON.stringify(beforeAbnormality[field]) !==
    JSON.stringify(afterAbnormality[field]));
  if (!raChanged && !sourceChanged) return null;

  const nextVersion = (warning.version as number) + 1;
  if (!Number.isSafeInteger(nextVersion)) {
    throw new ChargeAbnormalityMutationError(
      "failed-precondition",
      "The linked quality-warning version cannot advance safely.",
      {reasonCode: "charge-quality-warning-version-overflow"},
    );
  }
  const after: UserAuthorityJsonMap = {...warning};
  if (linkedTicketId == null) {
    Object.assign(after, {
      sourceVersion: afterAbnormality.version,
      sourceSummary: afterAbnormality.abnormalityTypeTitle,
      sourceSeverity: afterAbnormality.severity,
      warningReason: afterAbnormality.observedReason,
      affectedAssets: afterAbnormality.affectedAssets,
      component: afterAbnormality.component,
    });
  }
  if (raChanged) {
    if (afterAbnormality.reannealingStatus === "notRequired") {
      Object.assign(after, {
        status: "closed",
        closedAt: args.committedAt,
        closedByUid: args.actorUid,
        closedByName: args.actorName,
        closureDisposition: "coilFoundAcceptable",
        linkedReannealingChargeNos: [],
        decisionReason: args.reason,
      });
    } else if (afterAbnormality.reannealingStatus === "completed") {
      Object.assign(after, {
        status: "closed",
        closedAt: args.committedAt,
        closedByUid: args.actorUid,
        closedByName: args.actorName,
        closureDisposition: "reannealingCompleted",
        linkedReannealingChargeNos: [afterAbnormality.reannealedToChargeNo],
        decisionReason: args.reason,
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
  const hasWarningEvidence = Object.prototype.hasOwnProperty.call(
    receipt,
    "linkedWarningId",
  ) || Object.prototype.hasOwnProperty.call(
    receipt,
    "linkedWarningVersion",
  );
  if (hasWarningEvidence) {
    if (warning == null ||
        receipt.linkedWarningId !== warningId ||
        receipt.linkedWarningVersion !== warning.version) {
      throw new ChargeAbnormalityMutationError(
        "data-loss",
        "The linked quality-warning replay evidence has drifted.",
        {reasonCode: "abnormality-replay-warning-drift"},
      );
    }
  }
  if (
    Number.isSafeInteger(resultVersion) &&
    current.version !== resultVersion
  ) {
    throw new ChargeAbnormalityMutationError(
      "aborted",
      "The charge abnormality changed after the recorded mutation.",
      {reasonCode: "abnormality-replay-evidence-drift"},
    );
  }
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
    throw new ChargeAbnormalityMutationError(
      "data-loss",
      "The abnormality mutation receipt or audit is malformed.",
      {reasonCode: "abnormality-replay-evidence-malformed"},
    );
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
    abnormality: current,
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

  requireActor(await actorRef.get(), actorUid);
  if (args.beforeTransactionForTest != null) {
    await args.beforeTransactionForTest();
  }

  return db.runTransaction(async (transaction) => {
    const receiptSnapshot = await transaction.get(receiptRef);
    const actorSnapshot = await transaction.get(actorRef);
    const actor = requireActor(actorSnapshot, actorUid);
    const abnormalitySnapshot = await transaction.get(abnormalityRef);
    const auditSnapshot = await transaction.get(auditRef);

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
    const existing = validateExistingAbnormality(
      existingData,
      request.abnormalityId,
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
    if (warning != null &&
        (warning.sourceChargeNo !== existing.sourceChargeNo ||
          (linkedTicketId == null ?
            (warning.sourceType !== "abnormality" ||
              warning.sourceId !== request.abnormalityId ||
              (warning.sourceVersion as number) > (existing.version as number)) :
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
      const typeRef = db
        .collection("abnormality_types")
        .doc(request.update.abnormalityTypeId);
      type = canonicalType(
        await transaction.get(typeRef),
        request.update.abnormalityTypeId,
      );
    }

    const committedAtDate = now();
    const committedAtIso = committedAtDate.toISOString();
    const committedAt = timestampFromDate(committedAtDate);
    const resultVersion = request.expectedVersion + 1;
    if (!Number.isSafeInteger(resultVersion)) {
      throw new ChargeAbnormalityMutationError(
        "failed-precondition",
        "The charge-abnormality version cannot advance safely.",
        {reasonCode: "abnormality-version-overflow"},
      );
    }

    const after: UserAuthorityJsonMap = {...existing};
    if (request.update != null && type != null) {
      Object.assign(after, {
        abnormalityTypeId: request.update.abnormalityTypeId,
        abnormalityTypeTitle: type.title,
        abnormalityTypeCode: type.code,
        category: type.category,
        severity: request.update.severity,
        affectedAssets: request.update.affectedAssets,
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
    transaction.set(auditRef, {
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
    });
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
      abnormality: after,
    };
  });
}
