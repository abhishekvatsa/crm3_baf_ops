import {createHash} from "crypto";

import {canonicalModuleDiscipline, laneForModuleDiscipline} from "./maintenanceWorkflow/modulePolicy";
import {
  PersistedWorkPayloadError,
  readFieldDefinitionPayload,
} from "./persistedWorkPayload";
import {canonicalUserHasAnyRole} from "./userAuthority";
export type AssignmentHttpsErrorCode =
  | "invalid-argument"
  | "not-found"
  | "already-exists"
  | "permission-denied"
  | "failed-precondition"
  | "aborted"
  | "data-loss"
  | "internal"
  | "unauthenticated";

export type AssignmentJsonMap = {[key: string]: unknown};

export type AssignmentFirestoreLike = {
  collection: (name: string) => AssignmentCollectionLike;
  runTransaction: <T>(
    fn: (transaction: AssignmentTransactionLike) => Promise<T>,
  ) => Promise<T>;
};

type AssignmentCollectionLike = {
  doc: (id?: string) => AssignmentDocumentRefLike;
  where: (
    field: string,
    op: string,
    value: unknown,
  ) => AssignmentQueryLike;
};

type AssignmentQueryLike = {
  where: (
    field: string,
    op: string,
    value: unknown,
  ) => AssignmentQueryLike;
  get: () => Promise<AssignmentQuerySnapshotLike>;
};

type AssignmentDocumentRefLike = {
  id?: string;
  path?: string;
  get: () => Promise<AssignmentDocumentSnapshotLike>;
};

type AssignmentDocumentSnapshotLike = {
  exists: boolean;
  id?: string;
  data: () => AssignmentJsonMap | undefined;
};

type AssignmentQuerySnapshotLike = {
  docs: AssignmentDocumentSnapshotLike[];
};

type AssignmentTransactionLike = {
  get: (
    refOrQuery: AssignmentDocumentRefLike | AssignmentQueryLike,
  ) => Promise<
    AssignmentDocumentSnapshotLike | AssignmentQuerySnapshotLike
  >;
  set: (
    ref: AssignmentDocumentRefLike,
    data: AssignmentJsonMap,
    options?: AssignmentJsonMap,
  ) => void;
};

const ASSIGNER_ROLES = new Set([
  "admin",
  "si",
  "contractSupervisor",
  "shiftSupervisor",
  "seniorMechanical",
  "seniorElectrical",
  "seniorInstrumentation",
  "seniorRefractory",
]);

const ASSET_TYPES = new Set([
  "base",
  "furnace",
  "forceCooler",
  "innerCover",
  "governedCustom",
]);

const REQUEST_ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const CONTENT_HASH_PATTERN = /^tg2-sha256:[0-9a-f]{64}$/;
const MAX_MODULES_PER_ASSIGNMENT = 100;
const MAX_REMARKS_LENGTH = 2000;
const MODULE_POPULATION_SCHEMA_VERSION = 1;
const MAX_ASSIGNMENT_TRANSACTION_ATTEMPTS = 8;

export class AssignmentValidationError extends Error {
  readonly code: AssignmentHttpsErrorCode;
  readonly details?: unknown;

  constructor(
    code: AssignmentHttpsErrorCode,
    message: string,
    details?: unknown,
  ) {
    super(message);
    this.name = "AssignmentValidationError";
    this.code = code;
    this.details = details;
  }
}

interface ParsedAssignmentRequest {
  requestId: string;
  packageId: string;
  versionId: string;
  expectedVersionNumber: number;
  expectedContentHash: string;
  assetType: string;
  assetNumber: number;
  chargeNoAtEvent: number | null;
  remarks: string | null;
  payloadFingerprint: string;
}

interface ParsedSnapshotBundle {
  jobSnapshot: AssignmentJsonMap;
  moduleSnapshots: AssignmentJsonMap[];
  fieldDefinitions: AssignmentJsonMap[];
  checklistItems: AssignmentJsonMap[];
}

interface CanonicalAssignment {
  executionId: string;
  execution: AssignmentJsonMap;
  modules: Array<{
    id: string;
    data: AssignmentJsonMap;
  }>;
}

export interface PublishedTemplateAssignmentResult {
  ok: true;
  requestId: string;
  idempotentReplay: boolean;
  publicationAuditId: string;
  assignedAt: string;
  executionId: string;
  execution: AssignmentJsonMap;
  modules: AssignmentJsonMap[];
}

export function cleanOptionalText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function assertNonEmptyString(
  value: unknown,
  fieldName: string,
  maxLength = 512,
): string {
  const cleaned = cleanOptionalText(value);
  if (cleaned == null) {
    throw new AssignmentValidationError(
      "invalid-argument",
      `${fieldName} must be a non-empty string.`,
      {reasonCode: "missing-field", field: fieldName},
    );
  }
  if (cleaned.length > maxLength) {
    throw new AssignmentValidationError(
      "invalid-argument",
      `${fieldName} is too long.`,
      {reasonCode: "field-too-long", field: fieldName, maxLength},
    );
  }
  return cleaned;
}

function assertDocumentId(value: unknown, fieldName: string): string {
  const id = assertNonEmptyString(value, fieldName, 512);
  if (id === "." || id === ".." || id.includes("/")) {
    throw new AssignmentValidationError(
      "invalid-argument",
      `${fieldName} is not a valid Firestore document identity.`,
      {reasonCode: "invalid-document-id", field: fieldName},
    );
  }
  return id;
}

function assertReplayAssignedAt(
  receiptValue: unknown,
  executionValue: unknown,
): string {
  const receiptPresent = receiptValue != null;
  const executionPresent = executionValue != null;
  if (!receiptPresent && !executionPresent) {
    throw new AssignmentValidationError(
      "data-loss",
      "The completed assignment is missing its assignment timestamp.",
      {reasonCode: "request-assigned-at-missing"},
    );
  }

  const parse = (value: unknown, source: "receipt" | "execution"): Date => {
    const candidate = cleanOptionalText(value);
    const parsed = candidate == null ? null : new Date(candidate);
    if (parsed == null || Number.isNaN(parsed.getTime())) {
      throw new AssignmentValidationError(
        "data-loss",
        "The completed assignment has an invalid assignment timestamp.",
        {reasonCode: "request-assigned-at-invalid", source},
      );
    }
    if (parsed.toISOString() !== candidate) {
      throw new AssignmentValidationError(
        "data-loss",
        "The completed assignment timestamp is not canonical UTC ISO evidence.",
        {reasonCode: "request-assigned-at-invalid", source},
      );
    }
    return parsed;
  };

  const receiptAssignedAt = receiptPresent
    ? parse(receiptValue, "receipt")
    : null;
  const executionCreatedAt = executionPresent
    ? parse(executionValue, "execution")
    : null;
  if (
    receiptAssignedAt != null &&
    executionCreatedAt != null &&
    receiptAssignedAt.getTime() !== executionCreatedAt.getTime()
  ) {
    throw new AssignmentValidationError(
      "data-loss",
      "The completed assignment timestamp disagrees with its execution.",
      {reasonCode: "request-assigned-at-mismatch"},
    );
  }
  return (receiptAssignedAt ?? executionCreatedAt!).toISOString();
}

function assertPositiveSafeInteger(
  value: unknown,
  fieldName: string,
): number {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < 1
  ) {
    throw new AssignmentValidationError(
      "invalid-argument",
      `${fieldName} must be a positive integer.`,
      {reasonCode: "invalid-integer", field: fieldName},
    );
  }
  return value;
}

function parseOptionalSafeInteger(
  value: unknown,
  fieldName: string,
): number | null {
  if (value == null) return null;
  if (typeof value !== "number" || !Number.isSafeInteger(value)) {
    throw new AssignmentValidationError(
      "invalid-argument",
      `${fieldName} must be an integer when provided.`,
      {reasonCode: "invalid-integer", field: fieldName},
    );
  }
  return value;
}

function validateAssetNumber(assetType: string, assetNumber: number): void {
  const valid =
    assetType === "base"
      ? (assetNumber >= 101 && assetNumber <= 124) ||
        (assetNumber >= 201 && assetNumber <= 223)
      : assetType === "furnace"
        ? assetNumber >= 1 && assetNumber <= 26
        : assetType === "forceCooler"
          ? assetNumber >= 1 && assetNumber <= 25
          : assetType === "innerCover"
            ? assetNumber > 0
            : assetType === "governedCustom"
              ? assetNumber >= 1 && assetNumber <= 9999
            : false;
  if (!valid) {
    throw new AssignmentValidationError(
      "invalid-argument",
      `assetNumber is invalid for assetType ${assetType}.`,
      {
        reasonCode: "invalid-asset-number",
        assetType,
        assetNumber,
      },
    );
  }
}

export function assignmentRequestPayloadFingerprint(data: {
  packageId: string;
  versionId: string;
  expectedVersionNumber: number;
  expectedContentHash: string;
  assetType: string;
  assetNumber: number;
  chargeNoAtEvent: number | null;
  remarks: string | null;
}): string {
  const canonical = JSON.stringify({
    packageId: data.packageId,
    versionId: data.versionId,
    expectedVersionNumber: data.expectedVersionNumber,
    expectedContentHash: data.expectedContentHash,
    assetType: data.assetType,
    assetNumber: data.assetNumber,
    chargeNoAtEvent: data.chargeNoAtEvent,
    remarks: data.remarks,
  });
  return createHash("sha256").update(canonical, "utf8").digest("hex");
}

export function parsePublishedTemplateAssignmentRequest(
  raw: AssignmentJsonMap,
): ParsedAssignmentRequest {
  const requestId = assertNonEmptyString(raw.requestId, "requestId", 64);
  if (!REQUEST_ID_PATTERN.test(requestId)) {
    throw new AssignmentValidationError(
      "invalid-argument",
      "requestId must be a UUID.",
      {reasonCode: "invalid-request-id"},
    );
  }
  const packageId = assertDocumentId(raw.packageId, "packageId");
  const versionId = assertDocumentId(raw.versionId, "versionId");
  const expectedVersionNumber = assertPositiveSafeInteger(
    raw.expectedVersionNumber,
    "expectedVersionNumber",
  );
  const expectedContentHash = assertNonEmptyString(
    raw.expectedContentHash,
    "expectedContentHash",
    128,
  );
  if (!CONTENT_HASH_PATTERN.test(expectedContentHash)) {
    throw new AssignmentValidationError(
      "invalid-argument",
      "expectedContentHash is not a governed tg2 SHA-256 hash.",
      {reasonCode: "invalid-content-hash"},
    );
  }
  const assetType = assertNonEmptyString(raw.assetType, "assetType", 64);
  if (!ASSET_TYPES.has(assetType)) {
    throw new AssignmentValidationError(
      "invalid-argument",
      `Unsupported assetType ${assetType}.`,
      {reasonCode: "invalid-asset-type", assetType},
    );
  }
  const assetNumber = assertPositiveSafeInteger(
    raw.assetNumber,
    "assetNumber",
  );
  validateAssetNumber(assetType, assetNumber);
  const chargeNoAtEvent = parseOptionalSafeInteger(
    raw.chargeNoAtEvent,
    "chargeNoAtEvent",
  );
  const remarks = cleanOptionalText(raw.remarks);
  if (remarks != null && remarks.length > MAX_REMARKS_LENGTH) {
    throw new AssignmentValidationError(
      "invalid-argument",
      `remarks must not exceed ${MAX_REMARKS_LENGTH} characters.`,
      {reasonCode: "remarks-too-long", maxLength: MAX_REMARKS_LENGTH},
    );
  }

  const payloadFingerprint = assignmentRequestPayloadFingerprint({
    packageId,
    versionId,
    expectedVersionNumber,
    expectedContentHash,
    assetType,
    assetNumber,
    chargeNoAtEvent,
    remarks,
  });

  return {
    requestId,
    packageId,
    versionId,
    expectedVersionNumber,
    expectedContentHash,
    assetType,
    assetNumber,
    chargeNoAtEvent,
    remarks,
    payloadFingerprint,
  };
}

function asMap(value: unknown): AssignmentJsonMap {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return {...(value as AssignmentJsonMap)};
}

function parseJsonObject(raw: unknown, label: string): AssignmentJsonMap {
  const text = assertNonEmptyString(raw, label, 1_000_000);
  let decoded: unknown;
  try {
    decoded = JSON.parse(text);
  } catch {
    throw new AssignmentValidationError(
      "failed-precondition",
      `${label} is not valid JSON.`,
      {reasonCode: "invalid-snapshot-json", field: label},
    );
  }
  if (
    decoded == null ||
    typeof decoded !== "object" ||
    Array.isArray(decoded)
  ) {
    throw new AssignmentValidationError(
      "failed-precondition",
      `${label} must be a JSON object.`,
      {reasonCode: "invalid-snapshot-shape", field: label},
    );
  }
  return {...(decoded as AssignmentJsonMap)};
}

function parseJsonObjectList(
  raw: unknown,
  label: string,
  allowEmpty: boolean,
): AssignmentJsonMap[] {
  const text = assertNonEmptyString(raw, label, 4_000_000);
  let decoded: unknown;
  try {
    decoded = JSON.parse(text);
  } catch {
    throw new AssignmentValidationError(
      "failed-precondition",
      `${label} is not valid JSON.`,
      {reasonCode: "invalid-snapshot-json", field: label},
    );
  }
  if (!Array.isArray(decoded)) {
    throw new AssignmentValidationError(
      "failed-precondition",
      `${label} must be a JSON list.`,
      {reasonCode: "invalid-snapshot-shape", field: label},
    );
  }
  const objects = decoded.map((entry, index) => {
    if (
      entry == null ||
      typeof entry !== "object" ||
      Array.isArray(entry)
    ) {
      throw new AssignmentValidationError(
        "failed-precondition",
        `${label} item #${index + 1} must be a JSON object.`,
        {
          reasonCode: "invalid-snapshot-item",
          field: label,
          index,
        },
      );
    }
    return {...(entry as AssignmentJsonMap)};
  });
  if (!allowEmpty && objects.length === 0) {
    throw new AssignmentValidationError(
      "failed-precondition",
      `${label} must contain at least one item.`,
      {reasonCode: "empty-snapshot-list", field: label},
    );
  }
  return objects;
}

function parseSnapshotBundle(
  version: AssignmentJsonMap,
): ParsedSnapshotBundle {
  return {
    jobSnapshot: parseJsonObject(
      version.jobTemplateSnapshotJson,
      "jobTemplateSnapshotJson",
    ),
    moduleSnapshots: parseJsonObjectList(
      version.moduleSnapshotsJson,
      "moduleSnapshotsJson",
      false,
    ),
    fieldDefinitions: parseJsonObjectList(
      version.fieldDefinitionsJson,
      "fieldDefinitionsJson",
      true,
    ),
    checklistItems: parseJsonObjectList(
      version.checklistJson,
      "checklistJson",
      true,
    ),
  };
}

function stringValue(value: unknown): string | null {
  if (typeof value === "string") {
    const cleaned = value.trim();
    return cleaned.length === 0 ? null : cleaned;
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  return null;
}

function stringFrom(
  map: AssignmentJsonMap,
  keys: readonly string[],
): string | null {
  for (const key of keys) {
    const parsed = stringValue(map[key]);
    if (parsed != null) return parsed;
  }
  return null;
}

function intValue(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string") {
    const cleaned = value.trim();
    if (/^-?\d+$/.test(cleaned)) return Number(cleaned);
  }
  return null;
}

function boolValue(value: unknown): boolean | null {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (
      normalized === "true" ||
      normalized === "yes" ||
      normalized === "required"
    ) {
      return true;
    }
    if (
      normalized === "false" ||
      normalized === "no" ||
      normalized === "optional"
    ) {
      return false;
    }
  }
  return null;
}

function boolFrom(
  map: AssignmentJsonMap,
  keys: readonly string[],
  fallback: boolean,
): boolean {
  for (const key of keys) {
    const parsed = boolValue(map[key]);
    if (parsed != null) return parsed;
  }
  return fallback;
}

function stringList(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value
      .map((item) => String(item).trim())
      .filter((item) => item.length > 0);
  }
  if (typeof value === "string" && value.trim().length > 0) {
    return value
      .split(/[,;/|]+/)
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
  }
  return [];
}

function stringListFrom(
  map: AssignmentJsonMap,
  keys: readonly string[],
): string[] {
  for (const key of keys) {
    const list = stringList(map[key]);
    if (list.length > 0) return list;
  }
  return [];
}

function normalizeKey(value: string | null): string {
  return (value ?? "")
    .trim()
    .toLowerCase()
    .replaceAll("&", "and")
    .replace(/[^a-z0-9]+/g, "");
}

function canonicalSnapshotAssetType(value: string | null): string | null {
  switch (normalizeKey(value)) {
  case "base":
    return "base";
  case "furnace":
  case "baffurnace":
    return "furnace";
  case "forcecooler":
  case "forcedcooler":
  case "forcedcoolers":
  case "cooler":
    return "forceCooler";
  case "innercover":
  case "innercovers":
    return "innerCover";
  case "governedcustom":
    return "governedCustom";
  default:
    return null;
  }
}

type ValidatedAssignmentHierarchyReference = {
  scope: "definition" | "installedComponent";
  assetNumber: number | null;
};

function requiredHierarchyString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const cleaned = value.trim();
  return cleaned.length > 0 ? cleaned : null;
}

function optionalHierarchyString(
  value: unknown,
): string | null | undefined {
  if (value == null) return null;
  if (typeof value !== "string") return undefined;
  const cleaned = value.trim();
  return cleaned.length > 0 ? cleaned : null;
}

function optionalHierarchyPositiveInt(
  value: unknown,
): number | null | undefined {
  if (value == null) return null;
  if (!Number.isSafeInteger(value) || (value as number) < 1) return undefined;
  return value as number;
}

function optionalHierarchyStringList(
  value: unknown,
): ReadonlyArray<string> | null {
  if (value == null) return [];
  if (!Array.isArray(value)) return null;
  const result: string[] = [];
  for (const item of value) {
    const parsed = requiredHierarchyString(item);
    if (parsed == null) return null;
    result.push(parsed);
  }
  return result;
}

function validateHierarchyReferenceContract(
  reference: AssignmentJsonMap,
): ValidatedAssignmentHierarchyReference | null {
  const schemaVersion = reference.schemaVersion;
  if (!Number.isSafeInteger(schemaVersion) ||
      (schemaVersion !== 1 && schemaVersion !== 2)) {
    return null;
  }
  const scope = schemaVersion === 1 ? "definition" : reference.scope;
  if (scope !== "definition" && scope !== "installedComponent") return null;
  const nodeVersion = reference.nodeVersion;
  if (requiredHierarchyString(reference.assetClassId) == null ||
      requiredHierarchyString(reference.assetClassCode) == null ||
      requiredHierarchyString(reference.assetClassName) == null ||
      requiredHierarchyString(reference.nodeId) == null ||
      !Number.isSafeInteger(nodeVersion) || (nodeVersion as number) < 1 ||
      requiredHierarchyString(reference.nodeName) == null) {
    return null;
  }

  const assetInstanceId = optionalHierarchyString(reference.assetInstanceId);
  const assetInstanceVersion = optionalHierarchyPositiveInt(
    reference.assetInstanceVersion,
  );
  const assetNumber = optionalHierarchyPositiveInt(reference.assetNumber);
  const assetInstanceName = optionalHierarchyString(reference.assetInstanceName);
  const componentInstanceId = optionalHierarchyString(
    reference.componentInstanceId,
  );
  const componentInstanceVersion = optionalHierarchyPositiveInt(
    reference.componentInstanceVersion,
  );
  const componentTag = optionalHierarchyString(reference.componentTag);
  const hierarchyPath = optionalHierarchyStringList(reference.hierarchyPath);
  const ownerDiscipline = optionalHierarchyString(reference.ownerDiscipline);
  const accountableRoleKeys = optionalHierarchyStringList(
    reference.accountableRoleKeys,
  );
  if (assetInstanceId === undefined || assetInstanceVersion === undefined ||
      assetNumber === undefined || assetInstanceName === undefined ||
      componentInstanceId === undefined ||
      componentInstanceVersion === undefined || componentTag === undefined ||
      hierarchyPath == null || ownerDiscipline === undefined ||
      accountableRoleKeys == null) {
    return null;
  }

  const ownershipStatus = reference.ownershipStatus;
  if (ownershipStatus !== "unassigned" && ownershipStatus !== "provisional" &&
      ownershipStatus !== "confirmed") {
    return null;
  }
  if (ownershipStatus === "unassigned" &&
      (ownerDiscipline != null || accountableRoleKeys.length > 0)) {
    return null;
  }
  if (ownershipStatus === "provisional" &&
      ownerDiscipline == null && accountableRoleKeys.length === 0) {
    return null;
  }
  if (ownershipStatus === "confirmed" &&
      (ownerDiscipline == null || accountableRoleKeys.length === 0)) {
    return null;
  }
  if (scope === "installedComponent" &&
      (assetInstanceId == null || assetInstanceVersion == null ||
       assetNumber == null || assetInstanceName == null ||
       componentInstanceId == null || componentInstanceVersion == null ||
       ownershipStatus !== "confirmed")) {
    return null;
  }
  return {scope, assetNumber};
}

function validateAssignmentSnapshotTarget(
  bundle: ParsedSnapshotBundle,
  request: ParsedAssignmentRequest,
): void {
  const rawSnapshotType = stringFrom(bundle.jobSnapshot, [
    "assetType",
    "applicableAssetType",
    "asset_type",
  ]);
  const snapshotType = canonicalSnapshotAssetType(rawSnapshotType);
  if (rawSnapshotType != null && snapshotType == null) {
    throw new AssignmentValidationError(
      "failed-precondition",
      "The published snapshot has an unsupported asset type.",
      {reasonCode: "snapshot-asset-type-invalid"},
    );
  }
  if (snapshotType != null && snapshotType !== request.assetType) {
    throw new AssignmentValidationError(
      "failed-precondition",
      "The requested asset type does not match the published snapshot.",
      {
        reasonCode: "assignment-asset-type-mismatch",
        snapshotAssetType: snapshotType,
        requestedAssetType: request.assetType,
      },
    );
  }
  if (request.assetType !== "governedCustom") return;
  if (snapshotType !== "governedCustom") {
    throw new AssignmentValidationError(
      "failed-precondition",
      "Governed custom assignments require an explicit custom snapshot type.",
      {reasonCode: "custom-snapshot-asset-type-missing"},
    );
  }

  const encoded = cleanOptionalText(bundle.jobSnapshot.assetHierarchyRefJson);
  if (encoded == null) {
    throw new AssignmentValidationError(
      "failed-precondition",
      "Governed custom assignments require a published hierarchy reference.",
      {reasonCode: "custom-snapshot-hierarchy-reference-missing"},
    );
  }
  let reference: AssignmentJsonMap;
  try {
    const decoded: unknown = JSON.parse(encoded);
    if (decoded == null || typeof decoded !== "object" || Array.isArray(decoded)) {
      throw new Error("not an object");
    }
    reference = {...(decoded as AssignmentJsonMap)};
  } catch {
    throw new AssignmentValidationError(
      "failed-precondition",
      "The published custom hierarchy reference is malformed.",
      {reasonCode: "custom-snapshot-hierarchy-reference-invalid"},
    );
  }
  const validatedReference = validateHierarchyReferenceContract(reference);
  if (validatedReference == null) {
    throw new AssignmentValidationError(
      "failed-precondition",
      "The published custom hierarchy reference is incomplete.",
      {reasonCode: "custom-snapshot-hierarchy-reference-invalid"},
    );
  }
  if (
    validatedReference.scope === "installedComponent" &&
    validatedReference.assetNumber !== request.assetNumber
  ) {
    throw new AssignmentValidationError(
      "failed-precondition",
      "The installed-component snapshot does not match the requested asset number.",
      {reasonCode: "custom-snapshot-asset-number-mismatch"},
    );
  }
}

function moduleCode(module: AssignmentJsonMap): string | null {
  return stringFrom(module, ["moduleCode", "code", "moduleId", "id"]);
}

function moduleTitle(
  module: AssignmentJsonMap,
  index: number,
): string {
  return (
    stringFrom(module, [
      "moduleTitle",
      "title",
      "name",
      "displayTitle",
      "label",
    ]) ??
    moduleCode(module) ??
    `Module ${index + 1}`
  );
}

function fieldKey(field: AssignmentJsonMap): string | null {
  return stringFrom(field, ["key", "fieldKey", "fieldId", "id"]);
}

function fieldModuleCode(field: AssignmentJsonMap): string | null {
  return stringFrom(field, [
    "moduleCode",
    "moduleId",
    "templateModuleId",
    "parentModuleCode",
  ]);
}

function fieldsForModule(
  bundle: ParsedSnapshotBundle,
  module: AssignmentJsonMap,
): AssignmentJsonMap[] {
  const code = moduleCode(module);

  for (const key of [
    "fields",
    "fieldDefinitions",
    "fieldDefinitionsJson",
  ]) {
    const value = module[key];
    if (typeof value === "string") {
      const parsed = parseJsonObjectList(
        value,
        `embedded ${key} for module ${code ?? "unknown"}`,
        true,
      );
      if (parsed.length > 0) return parsed;
    }
    if (Array.isArray(value)) {
      const parsed = value.map((entry, index) => {
        if (
          entry == null ||
          typeof entry !== "object" ||
          Array.isArray(entry)
        ) {
          throw new AssignmentValidationError(
            "failed-precondition",
            `embedded ${key} item #${index + 1} for module ${
              code ?? "unknown"
            } must be a JSON object.`,
            {reasonCode: "invalid-embedded-field"},
          );
        }
        return {...(entry as AssignmentJsonMap)};
      });
      if (parsed.length > 0) return parsed;
    }
  }

  const hasLinkedGlobalFields = bundle.fieldDefinitions.some((field) => {
    const linked = fieldModuleCode(field);
    return linked != null && linked.trim().length > 0;
  });

  if (code != null && code.trim().length > 0) {
    const normalizedCode = normalizeKey(code);
    const filtered = bundle.fieldDefinitions.filter(
      (field) => normalizeKey(fieldModuleCode(field)) === normalizedCode,
    );
    if (filtered.length > 0) return filtered;
  }

  return hasLinkedGlobalFields ? [] : bundle.fieldDefinitions;
}

function validatedFieldsForModule(
  bundle: ParsedSnapshotBundle,
  module: AssignmentJsonMap,
): AssignmentJsonMap[] {
  const code = moduleCode(module) ?? "unknown";
  const fields = fieldsForModule(bundle, module);
  try {
    return [...readFieldDefinitionPayload(JSON.stringify(fields), {
      field: `fieldDefinitionsJson for module ${code}`,
    }).rows];
  } catch (error) {
    if (error instanceof PersistedWorkPayloadError) {
      throw new AssignmentValidationError(
        "failed-precondition",
        `Field definitions for module ${code} are invalid.`,
        {
          reasonCode: "field-definition-payload-invalid",
          moduleCode: code,
          field: error.field,
        },
      );
    }
    throw error;
  }
}

function validateSnapshotBundle(bundle: ParsedSnapshotBundle): void {
  if (bundle.moduleSnapshots.length > MAX_MODULES_PER_ASSIGNMENT) {
    throw new AssignmentValidationError(
      "failed-precondition",
      `TemplateVersion contains more than ${MAX_MODULES_PER_ASSIGNMENT} modules.`,
      {
        reasonCode: "too-many-modules",
        maxModules: MAX_MODULES_PER_ASSIGNMENT,
      },
    );
  }

  const moduleCodes = new Map<string, string>();
  const fieldKeysByModule = new Map<string, Set<string>>();

  bundle.moduleSnapshots.forEach((module, index) => {
    const code = moduleCode(module);
    if (code == null) {
      throw new AssignmentValidationError(
        "failed-precondition",
        `Module #${index + 1} is missing moduleCode/code.`,
        {reasonCode: "module-code-missing", moduleIndex: index},
      );
    }
    const normalized = normalizeKey(code);
    if (moduleCodes.has(normalized)) {
      throw new AssignmentValidationError(
        "failed-precondition",
        `Duplicate module code "${code}".`,
        {reasonCode: "duplicate-module-code", moduleCode: code},
      );
    }
    moduleCodes.set(normalized, code);
    fieldKeysByModule.set(normalized, new Set<string>());
    if (
      stringFrom(module, [
        "moduleTitle",
        "title",
        "name",
        "displayTitle",
        "label",
      ]) == null
    ) {
      throw new AssignmentValidationError(
        "failed-precondition",
        `Module ${code} is missing moduleTitle/title.`,
        {reasonCode: "module-title-missing", moduleCode: code},
      );
    }
  });

  bundle.fieldDefinitions.forEach((field, index) => {
    const key = fieldKey(field);
    const label = stringFrom(field, ["label", "title", "name"]);
    const linkedCode = fieldModuleCode(field);
    if (key == null) {
      throw new AssignmentValidationError(
        "failed-precondition",
        `Field definition #${index + 1} is missing key.`,
        {reasonCode: "field-key-missing", fieldIndex: index},
      );
    }
    if (label == null) {
      throw new AssignmentValidationError(
        "failed-precondition",
        `Field definition #${index + 1} is missing label.`,
        {reasonCode: "field-label-missing", fieldIndex: index},
      );
    }
    if (linkedCode == null) {
      throw new AssignmentValidationError(
        "failed-precondition",
        `Field ${key} is missing moduleCode.`,
        {reasonCode: "field-module-missing", fieldKey: key},
      );
    }
    const normalizedModule = normalizeKey(linkedCode);
    const knownKeys = fieldKeysByModule.get(normalizedModule);
    if (knownKeys == null) {
      throw new AssignmentValidationError(
        "failed-precondition",
        `Field ${key} points to unknown moduleCode "${linkedCode}".`,
        {
          reasonCode: "field-module-unknown",
          fieldKey: key,
          moduleCode: linkedCode,
        },
      );
    }
    const normalizedField = normalizeKey(key);
    if (knownKeys.has(normalizedField)) {
      throw new AssignmentValidationError(
        "failed-precondition",
        `Duplicate field key "${key}" inside module ${linkedCode}.`,
        {
          reasonCode: "duplicate-field-key",
          fieldKey: key,
          moduleCode: linkedCode,
        },
      );
    }
    knownKeys.add(normalizedField);
  });

  bundle.checklistItems.forEach((item, index) => {
    const linkedCode = fieldModuleCode(item);
    if (linkedCode == null) return;
    const knownKeys = fieldKeysByModule.get(normalizeKey(linkedCode));
    if (knownKeys == null) {
      throw new AssignmentValidationError(
        "failed-precondition",
        `Checklist item #${index + 1} points to unknown moduleCode "${linkedCode}".`,
        {
          reasonCode: "checklist-module-unknown",
          checklistIndex: index,
        },
      );
    }
    const linkedField = stringFrom(item, [
      "linkedFieldKey",
      "fieldKey",
      "fieldId",
    ]);
    if (
      linkedField != null &&
      !knownKeys.has(normalizeKey(linkedField))
    ) {
      throw new AssignmentValidationError(
        "failed-precondition",
        `Checklist item #${index + 1} links to missing field "${linkedField}".`,
        {
          reasonCode: "checklist-field-unknown",
          checklistIndex: index,
        },
      );
    }
  });
}

function deriveClosureState(
  bundle: ParsedSnapshotBundle,
): {
  confirmed: boolean;
  criticalModuleCount: number;
  confirmedByUid: string | null;
  confirmedByName: string | null;
  confirmedAt: string | null;
} {
  const composer = asMap(bundle.jobSnapshot.composer);
  const actualCount = bundle.moduleSnapshots.filter((module) =>
    boolFrom(
      module,
      [
        "requiredForClosure",
        "requiredForCloseout",
        "required",
        "isRequired",
      ],
      false,
    ),
  ).length;
  const declaredCount =
    intValue(bundle.jobSnapshot.closureCriticalCount) ?? 0;
  const rawDate = cleanOptionalText(composer.closureReviewConfirmedAt);
  let confirmedAt: string | null = null;
  if (rawDate != null) {
    const date = new Date(rawDate);
    if (!Number.isNaN(date.getTime())) confirmedAt = date.toISOString();
  }
  return {
    confirmed: boolValue(composer.closureReviewConfirmed) ?? false,
    criticalModuleCount: Math.max(actualCount, declaredCount),
    confirmedByUid: cleanOptionalText(
      composer.closureReviewConfirmedByUid,
    ),
    confirmedByName: cleanOptionalText(
      composer.closureReviewConfirmedByName,
    ),
    confirmedAt,
  };
}

export function computeTemplateVersionContentHash(
  version: AssignmentJsonMap,
): string {
  const bundle = parseSnapshotBundle(version);
  const closure = deriveClosureState(bundle);
  const canonical = JSON.stringify({
    jobTemplateSnapshotJson: assertNonEmptyString(
      version.jobTemplateSnapshotJson,
      "jobTemplateSnapshotJson",
      1_000_000,
    ),
    moduleSnapshotsJson: assertNonEmptyString(
      version.moduleSnapshotsJson,
      "moduleSnapshotsJson",
      4_000_000,
    ),
    fieldDefinitionsJson: assertNonEmptyString(
      version.fieldDefinitionsJson,
      "fieldDefinitionsJson",
      4_000_000,
    ),
    checklistJson: assertNonEmptyString(
      version.checklistJson,
      "checklistJson",
      4_000_000,
    ),
    closureReviewConfirmed: closure.confirmed,
    closureCriticalModuleCount: closure.criticalModuleCount,
    closureReviewConfirmedByUid: closure.confirmedByUid,
    closureReviewConfirmedByName: closure.confirmedByName,
    closureReviewConfirmedAt: closure.confirmedAt,
    targetRefs: Array.isArray(version.targetRefs) ? version.targetRefs : [],
    deviceTagRefs: Array.isArray(version.deviceTagRefs)
      ? version.deviceTagRefs
      : [],
    safetyClass: cleanOptionalText(version.safetyClass),
    safetyGatePolicyJson: cleanOptionalText(
      version.safetyGatePolicyJson,
    ),
    procedureRefs: Array.isArray(version.procedureRefs)
      ? version.procedureRefs
      : [],
    operationalStatePreconditions: Array.isArray(
      version.operationalStatePreconditions,
    )
      ? version.operationalStatePreconditions
      : [],
    schemaVersion:
      typeof version.schemaVersion === "number"
        ? Math.trunc(version.schemaVersion)
        : 1,
  });
  return `tg2-sha256:${createHash("sha256")
    .update(canonical, "utf8")
    .digest("hex")}`;
}

function normalizeAgency(value: string): string {
  switch (normalizeKey(value)) {
    case "mechanical":
      return "mechanical";
    case "electrical":
      return "electrical";
    case "instrumentation":
    case "instrument":
    case "ia":
    case "ianda":
      return "instrumentation";
    case "operations":
      return "operations";
    case "refractory":
    case "others":
      return "refractory";
    case "shared":
      return "shared";
    case "safety":
      return "safety";
    default:
      return normalizeKey(value);
  }
}

function assignedAgencies(
  packageData: AssignmentJsonMap,
  jobSnapshot: AssignmentJsonMap,
): string[] {
  const combined = new Set<string>();
  for (const item of stringListFrom(jobSnapshot, [
    "assignedAgencies",
    "agencies",
    "disciplines",
    "disciplineScope",
  ])) {
    const normalized = normalizeAgency(item);
    if (normalized.length > 0) combined.add(normalized);
  }
  for (const item of stringList(packageData.disciplineScope)) {
    const normalized = normalizeAgency(item);
    if (normalized.length > 0) combined.add(normalized);
  }
  const sorted = [...combined].sort();
  return sorted.length === 0 ? ["mechanical"] : sorted;
}

function parseUseMode(value: unknown): string {
  const normalized = normalizeKey(stringValue(value));
  const values = [
    "scheduledPM",
    "troubleshooting",
    "correctiveFollowUp",
    "shutdownWork",
    "preStartVerification",
    "postRepairVerification",
    "futurePackage",
    "adHoc",
  ];
  return (
    values.find((item) => normalizeKey(item) === normalized) ??
    "scheduledPM"
  );
}

function parseDiscipline(value: unknown): string {
  return canonicalModuleDiscipline(value);
}

function laneKeyForDiscipline(value: string): string {
  return laneForModuleDiscipline(value);
}

function parseSafetyClass(value: unknown): string {
  const values = [
    "normal",
    "lotoRequired",
    "gasRisk",
    "hotSurface",
    "pressureTest",
    "liftingRisk",
    "electricalPanel",
    "combustionSpecialist",
    "configurationControl",
  ];
  const normalized = normalizeKey(stringValue(value));
  return (
    values.find((item) => normalizeKey(item) === normalized) ?? "normal"
  );
}

function jsonStringOrNull(value: unknown): string | null {
  if (value == null) return null;
  if (typeof value === "string") return cleanOptionalText(value);
  if (typeof value === "object") return JSON.stringify(value, null, 2);
  return null;
}

function moduleTags(
  packageData: AssignmentJsonMap,
  version: AssignmentJsonMap,
  snapshot: AssignmentJsonMap,
  code: string | null,
): string[] {
  const tags = new Set<string>();
  const packageCode = cleanOptionalText(packageData.packageCode);
  if (packageCode != null) tags.add(packageCode);
  if (code != null) tags.add(code);
  for (const item of stringList(snapshot.tags)) tags.add(item);
  for (const item of stringListFrom(snapshot, [
    "procedureRefs",
    "procedures",
  ])) {
    tags.add(item);
  }
  tags.add(`templateVersion:v${String(version.versionNumber)}`);
  return [...tags].filter((item) => item.trim().length > 0).sort();
}

export function userCanAssignPublishedTemplate(
  userData: AssignmentJsonMap,
): boolean {
  return canonicalUserHasAnyRole(userData, ASSIGNER_ROLES);
}

function snapshotData(
  snapshot: AssignmentDocumentSnapshotLike,
  label: string,
): AssignmentJsonMap {
  if (!snapshot.exists) {
    throw new AssignmentValidationError(
      "not-found",
      `${label} was not found.`,
      {reasonCode: `${label.toLowerCase().replaceAll(" ", "-")}-missing`},
    );
  }
  return snapshot.data() ?? {};
}

function authorizedAssignmentActorData(
  snapshot: AssignmentDocumentSnapshotLike | AssignmentQuerySnapshotLike,
): AssignmentJsonMap {
  if ("docs" in snapshot) {
    throw new AssignmentValidationError(
      "internal",
      "User lookup returned an invalid response.",
    );
  }
  const userData = snapshotData(snapshot, "User");
  if (!userCanAssignPublishedTemplate(userData)) {
    throw new AssignmentValidationError(
      "permission-denied",
      "This account is not authorized to assign governed jobs.",
      {reasonCode: "assignment-role-denied"},
    );
  }
  return userData;
}

function queryDocs(
  snapshot:
    | AssignmentDocumentSnapshotLike
    | AssignmentQuerySnapshotLike,
): AssignmentDocumentSnapshotLike[] {
  return "docs" in snapshot ? snapshot.docs : [];
}

type AssignmentEquipmentFacts = {
  activeNonRedMaintenanceCount: number;
  activeRedWorkCount: number;
  awaitingPreparationCount: number;
};

type AssignmentEquipmentProjection = AssignmentEquipmentFacts & {
  data: AssignmentJsonMap;
  version: number;
};

const MAX_EQUIPMENT_PROJECTION_RECONCILIATION_ATTEMPTS = 5;

function equipmentProjectionCounter(
  data: AssignmentJsonMap,
  field: string,
  options: {allowMissing?: boolean} = {},
): number | null {
  const value = data[field];
  if (value == null && options.allowMissing === true) return null;
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < 0
  ) {
    throw new AssignmentValidationError(
      "failed-precondition",
      `The equipment projection has an invalid ${field} counter.`,
      {
        reasonCode: "equipment-projection-counter-invalid",
        field,
        value,
      },
    );
  }
  return value;
}

function equipmentStateFromFacts(
  facts: AssignmentEquipmentFacts,
): "underRED" | "awaitingPreparation" | "underMaintenance" | null {
  if (facts.activeRedWorkCount > 0) return "underRED";
  if (facts.awaitingPreparationCount > 0) return "awaitingPreparation";
  if (facts.activeNonRedMaintenanceCount > 0) return "underMaintenance";
  return null;
}

function workflowFactsFromSnapshot(
  snapshot: AssignmentQuerySnapshotLike,
): AssignmentEquipmentFacts {
  let activeNonRedMaintenanceCount = 0;
  let activeRedWorkCount = 0;
  let awaitingPreparationCount = 0;
  for (const row of queryDocs(snapshot)) {
    const data = row.data() ?? {};
    if (
      data.status === "completed" ||
      data.status === "cancelled" ||
      data.cancelled === true
    ) {
      continue;
    }
    if (data.activeRedWork === true) activeRedWorkCount += 1;
    else if (data.awaitingPreparation === true) awaitingPreparationCount += 1;
    else activeNonRedMaintenanceCount += 1;
  }
  return {
    activeNonRedMaintenanceCount,
    activeRedWorkCount,
    awaitingPreparationCount,
  };
}

async function loadOpenWorkflowFacts(
  db: AssignmentFirestoreLike,
  request: ParsedAssignmentRequest,
): Promise<AssignmentEquipmentFacts> {
  const snapshot = await db
    .collection("maintenance_workflows")
    .where("assetTypeKey", "==", request.assetType)
    .where("assetNumber", "==", request.assetNumber)
    .get();
  return workflowFactsFromSnapshot(snapshot);
}

function factsEqual(
  left: AssignmentEquipmentFacts,
  right: AssignmentEquipmentFacts,
): boolean {
  return left.activeNonRedMaintenanceCount ===
      right.activeNonRedMaintenanceCount &&
    left.activeRedWorkCount === right.activeRedWorkCount &&
    left.awaitingPreparationCount === right.awaitingPreparationCount;
}

function equipmentProjectionRefreshRequired(
  data: AssignmentJsonMap,
  facts: AssignmentEquipmentFacts,
): never {
  throw new AssignmentValidationError(
    "aborted",
    "The equipment projection changed while workflow facts were being reconciled.",
    {
      reasonCode: "equipment-projection-refresh-required",
      projection: {
        activeNonRedMaintenanceCount:
          data.activeNonRedMaintenanceCount ?? null,
        activeRedWorkCount: data.activeRedWorkCount ?? null,
        awaitingPreparationCount: data.awaitingPreparationCount ?? null,
        version: data.version ?? null,
        state: data.state ?? null,
      },
      workflowFacts: facts,
    },
  );
}

function serializedEquipmentProjection(
  snapshot: AssignmentDocumentSnapshotLike,
  request: ParsedAssignmentRequest,
  workflowFacts: AssignmentEquipmentFacts,
): AssignmentEquipmentProjection {
  if (!snapshot.exists) {
    return {
      data: {},
      ...workflowFacts,
      version: 0,
    };
  }

  const data = snapshot.data() ?? {};
  const actualAssetTypeKey = cleanOptionalText(data.assetTypeKey);
  const actualAssetNumber = data.assetNumber;
  if (
    (actualAssetTypeKey != null && actualAssetTypeKey !== request.assetType) ||
    (actualAssetNumber != null && actualAssetNumber !== request.assetNumber)
  ) {
    throw new AssignmentValidationError(
      "failed-precondition",
      "The equipment projection identity does not match the assignment target.",
      {
        reasonCode: "equipment-projection-identity-mismatch",
        expectedAssetTypeKey: request.assetType,
        expectedAssetNumber: request.assetNumber,
        actualAssetTypeKey: actualAssetTypeKey ?? null,
        actualAssetNumber: actualAssetNumber ?? null,
      },
    );
  }

  const rawCounters = {
    activeNonRedMaintenanceCount: equipmentProjectionCounter(
      data,
      "activeNonRedMaintenanceCount",
      {allowMissing: true},
    ),
    activeRedWorkCount: equipmentProjectionCounter(
      data,
      "activeRedWorkCount",
      {allowMissing: true},
    ),
    awaitingPreparationCount: equipmentProjectionCounter(
      data,
      "awaitingPreparationCount",
      {allowMissing: true},
    ),
  };
  const presentCounterCount = Object.values(rawCounters)
    .filter((value) => value != null).length;
  if (presentCounterCount !== 0 && presentCounterCount !== 3) {
    throw new AssignmentValidationError(
      "failed-precondition",
      "The equipment projection has an incomplete workflow-counter set.",
      {
        reasonCode: "equipment-projection-counter-set-incomplete",
        counters: rawCounters,
      },
    );
  }

  const projectionFacts: AssignmentEquipmentFacts = presentCounterCount === 0
    ? workflowFacts
    : {
      activeNonRedMaintenanceCount:
        rawCounters.activeNonRedMaintenanceCount as number,
      activeRedWorkCount: rawCounters.activeRedWorkCount as number,
      awaitingPreparationCount: rawCounters.awaitingPreparationCount as number,
    };
  if (presentCounterCount === 3 && !factsEqual(projectionFacts, workflowFacts)) {
    equipmentProjectionRefreshRequired(data, workflowFacts);
  }

  const expectedState = equipmentStateFromFacts(workflowFacts);
  const actualState = cleanOptionalText(data.state);
  const zeroCountStateValid =
    expectedState == null &&
    (actualState === "available" || actualState === "inService");
  if (actualState !== expectedState && !zeroCountStateValid) {
    throw new AssignmentValidationError(
      "failed-precondition",
      "The equipment projection state does not match the current workflow facts.",
      {
        reasonCode: "equipment-projection-state-mismatch",
        expectedState: expectedState ?? "available-or-inService",
        actualState,
        workflowFacts,
      },
    );
  }

  const version = equipmentProjectionCounter(
    data,
    "version",
    {allowMissing: true},
  ) ?? 0;
  if (workflowFacts.activeNonRedMaintenanceCount === Number.MAX_SAFE_INTEGER) {
    throw new AssignmentValidationError(
      "failed-precondition",
      "The equipment projection maintenance counter cannot be incremented safely.",
      {reasonCode: "equipment-projection-counter-overflow"},
    );
  }

  return {
    data,
    ...workflowFacts,
    version,
  };
}

function assignmentReasonCode(error: unknown): string | null {
  if (!(error instanceof AssignmentValidationError)) return null;
  if (error.details == null || typeof error.details !== "object") return null;
  const reasonCode = (error.details as AssignmentJsonMap).reasonCode;
  return typeof reasonCode === "string" ? reasonCode : null;
}

function isRetryableClosedTransactionError(error: unknown): boolean {
  if (error == null || typeof error !== "object") return false;
  const candidate = error as {
    code?: unknown;
    message?: unknown;
    details?: unknown;
  };
  const numericCode =
    candidate.code === 3 ||
    candidate.code === "3";
  const namedCode =
    typeof candidate.code === "string" &&
    candidate.code.trim().toLowerCase() === "invalid-argument";
  if (!numericCode && !namedCode) return false;

  const message = typeof candidate.message === "string"
    ? candidate.message
    : "";
  const details = typeof candidate.details === "string"
    ? candidate.details
    : "";
  return `${message}\n${details}`
    .toLowerCase()
    .includes("transaction is invalid or closed");
}

function dateSortValue(value: unknown): number {
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? 0 : parsed;
  }
  if (
    value != null &&
    typeof value === "object" &&
    "toDate" in value &&
    typeof (value as {toDate?: unknown}).toDate === "function"
  ) {
    try {
      return (
        value as {toDate: () => Date}
      ).toDate().getTime();
    } catch {
      return 0;
    }
  }
  return 0;
}

function selectPublicationAudit(
  auditSnapshots: AssignmentDocumentSnapshotLike[],
  packageId: string,
  versionId: string,
  contentHash: string,
  publishedByUid: string | null,
): {id: string; data: AssignmentJsonMap} {
  const candidates = auditSnapshots
    .map((snapshot) => ({
      id: snapshot.id ?? "",
      data: snapshot.data() ?? {},
    }))
    .filter(
      (entry) =>
        entry.id.length > 0 &&
        cleanOptionalText(entry.data.firestoreId) === entry.id &&
        entry.data.isDeleted !== true &&
        entry.data.action === "published" &&
        cleanOptionalText(entry.data.packageFirestoreId) === packageId &&
        cleanOptionalText(entry.data.versionFirestoreId) === versionId &&
        cleanOptionalText(entry.data.afterHash) === contentHash &&
        (publishedByUid == null ||
          cleanOptionalText(entry.data.performedByUid) ===
            publishedByUid),
    )
    .sort(
      (a, b) =>
        dateSortValue(b.data.performedAt) -
        dateSortValue(a.data.performedAt),
    );
  const selected = candidates[0];
  if (selected == null) {
    throw new AssignmentValidationError(
      "not-found",
      "No matching remotely confirmed publication audit exists.",
      {
        reasonCode: "publication-audit-missing",
        packageId,
        versionId,
        contentHash,
      },
    );
  }
  const selectedTime = dateSortValue(selected.data.performedAt);
  const equallyAuthoritative = candidates.filter(
    (candidate) => dateSortValue(candidate.data.performedAt) === selectedTime,
  );
  if (equallyAuthoritative.length > 1) {
    throw new AssignmentValidationError(
      "failed-precondition",
      "Multiple equally authoritative publication audits exist.",
      {
        reasonCode: "publication-audit-ambiguous",
        packageId,
        versionId,
        contentHash,
        auditIds: equallyAuthoritative.map((candidate) => candidate.id).sort(),
      },
    );
  }
  return selected;
}

function canonicalTemplateName(
  packageData: AssignmentJsonMap,
  jobSnapshot: AssignmentJsonMap,
): string {
  return (
    stringFrom(jobSnapshot, [
      "jobName",
      "templateName",
      "title",
      "name",
    ]) ??
    cleanOptionalText(packageData.title) ??
    "Published template"
  );
}

function buildCanonicalAssignment(args: {
  db: AssignmentFirestoreLike;
  request: ParsedAssignmentRequest;
  actorUid: string;
  actorName: string | null;
  packageData: AssignmentJsonMap;
  versionData: AssignmentJsonMap;
  publicationAuditId: string;
  assignedAt: string;
}): CanonicalAssignment {
  const {
    db,
    request,
    actorUid,
    actorName,
    packageData,
    versionData,
    publicationAuditId,
    assignedAt,
  } = args;
  const bundle = parseSnapshotBundle(versionData);
  validateSnapshotBundle(bundle);
  validateAssignmentSnapshotTarget(bundle, request);

  const executionRef = db.collection("job_executions").doc();
  const executionId = assertDocumentId(
    executionRef.id,
    "generated execution ID",
  );
  const templateName = canonicalTemplateName(
    packageData,
    bundle.jobSnapshot,
  );
  const agencies = assignedAgencies(packageData, bundle.jobSnapshot);
  const packageCode = cleanOptionalText(packageData.packageCode);

  const execution: AssignmentJsonMap = {
    firestoreId: executionId,
    templateFirestoreId: request.versionId,
    templateName,
    templatePackageId: request.packageId,
    templateVersionId: request.versionId,
    templateVersionNumber: request.expectedVersionNumber,
    templateVersionLabel: cleanOptionalText(versionData.versionLabel),
    templateContentHash: request.expectedContentHash,
    templatePackageCode: packageCode,
    assetType: request.assetType,
    assetNumber: request.assetNumber,
    isCompleted: false,
    assignedByUid: actorUid,
    assignedByName: actorName,
    assignedAgencies: agencies,
    workflowSchemaVersion: 1,
    laneSetVersion: 0,
    laneSetFinalizedAt: null,
    laneSetFinalizedByUid: null,
    laneSetFinalizedByName: null,
    laneMappingReview: agencies.length > 0,
    parentExecutionFirestoreId: null,
    spawnedRedExecutionFirestoreId: null,
    redAnswerJson: null,
    completedByUid: null,
    completedByName: null,
    remarks: request.remarks,
    teamsInvolved: [],
    chargeNoAtEvent: request.chargeNoAtEvent,
    responsesJson: "[]",
    actionsJson: "[]",
    version: 1,
    modulePopulationVersion: 1,
    modulePopulationSchemaVersion: MODULE_POPULATION_SCHEMA_VERSION,
    modulePopulationUpdatedAt: assignedAt,
    modulePopulationUpdatedByUid: actorUid,
    modulePopulationLastMutation: "governedAssignment",
    modulePopulationLastModuleId: null,
    metadataJson: JSON.stringify({
      source: "server_governed_published_template_assignment",
      requestId: request.requestId,
      publicationAuditId,
      packageFirestoreId: request.packageId,
      packageCode,
      packageTitle: cleanOptionalText(packageData.title),
      versionFirestoreId: request.versionId,
      versionNumber: request.expectedVersionNumber,
      versionLabel: cleanOptionalText(versionData.versionLabel),
      contentHash: request.expectedContentHash,
      jobTemplateSnapshot: bundle.jobSnapshot,
    }),
    isDeleted: false,
    deletedAt: null,
    deletedByUid: null,
    deletedByName: null,
    deleteReason: null,
    createdAt: assignedAt,
    completedAt: null,
    updatedAt: assignedAt,
  };

  const modules = bundle.moduleSnapshots.map((snapshot, index) => {
    const moduleRef = db.collection("job_modules").doc();
    const moduleId = assertDocumentId(
      moduleRef.id,
      `generated module ID #${index + 1}`,
    );
    const code = moduleCode(snapshot);
    const fields = validatedFieldsForModule(bundle, snapshot);
    const discipline = parseDiscipline(
      stringFrom(snapshot, [
        "discipline",
        "defaultDiscipline",
        "assignedDiscipline",
        "ownerDiscipline",
      ]),
    );
    const data: AssignmentJsonMap = {
      firestoreId: moduleId,
      jobExecutionFirestoreId: executionId,
      jobExecutionLocalId: null,
      templateFirestoreId: request.versionId,
      templateName,
      templatePackageId: request.packageId,
      templateVersionId: request.versionId,
      templateModuleId: stringFrom(snapshot, [
        "templateModuleId",
        "moduleId",
        "id",
        "key",
      ]),
      moduleCode: code,
      moduleSnapshotJson: JSON.stringify(snapshot, null, 2),
      fieldDefinitionsJson: JSON.stringify(fields, null, 2),
      assetType: request.assetType,
      assetNumber: request.assetNumber,
      chargeNoAtEvent: request.chargeNoAtEvent,
      pairedEquipmentJson: jsonStringOrNull(
        snapshot.pairedEquipmentJson,
      ),
      moduleTitle: moduleTitle(snapshot, index),
      moduleDescription: stringFrom(snapshot, [
        "moduleDescription",
        "description",
        "closedDossierOutput",
      ]),
      status: "notStarted",
      useMode: parseUseMode(
        stringFrom(snapshot, ["useMode", "defaultUseMode"]),
      ),
      discipline,
      laneKey: laneKeyForDiscipline(discipline),
      laneActivationGeneration: 1,
      workflowLaneFirestoreId: `${executionId}_${laneKeyForDiscipline(discipline)}_1`,
      isOpenForWork: true,
      safetyClass: parseSafetyClass(
        stringFrom(snapshot, [
          "safetyClass",
          "defaultSafetyClass",
        ]),
      ),
      isRequired: boolFrom(
        snapshot,
        ["isRequired", "required"],
        true,
      ),
      requiredForClosure: boolFrom(
        snapshot,
        [
          "requiredForClosure",
          "requiredForCloseout",
          "required",
        ],
        true,
      ),
      addedDuringExecution: false,
      displayOrder:
        intValue(
          stringFrom(snapshot, [
            "displayOrder",
            "order",
            "sequence",
          ]) ?? snapshot.displayOrder,
        ) ?? index,
      functionalSection: stringFrom(snapshot, [
        "functionalSection",
        "section",
      ]),
      componentGroup: stringFrom(snapshot, [
        "componentGroup",
        "component",
      ]),
      subsystem: stringFrom(snapshot, [
        "subsystem",
        "catalogueArea",
        "area",
      ]),
      targetRef: stringFrom(snapshot, ["targetRef"]),
      targetRefs: stringListFrom(snapshot, ["targetRefs", "targets"]),
      procedureRefs: stringListFrom(snapshot, [
        "procedureRefs",
        "procedures",
      ]),
      safetyConfirmations: stringListFrom(snapshot, [
        "safetyConfirmations",
      ]),
      tags: moduleTags(
        packageData,
        versionData,
        snapshot,
        code,
      ),
      operationalStatePreconditions: stringListFrom(snapshot, [
        "operationalStatePreconditions",
        "preconditions",
      ]),
      responsesJson: "[]",
      actionsJson: "[]",
      draftNote: null,
      submissionNote: null,
      acceptanceNote: null,
      reopenReason: null,
      notApplicableReason: null,
      pendingIssue: null,
      requiresFollowUp: false,
      addedByUid: actorUid,
      addedByName: actorName,
      addedAt: assignedAt,
      addReason:
        `Assigned from published TemplateVersion v${request.expectedVersionNumber}`,
      createdByUid: actorUid,
      createdByName: actorName,
      createdAt: assignedAt,
      updatedByUid: actorUid,
      updatedByName: actorName,
      updatedAt: assignedAt,
      submittedByUid: null,
      submittedByName: null,
      submittedAt: null,
      acceptedByUid: null,
      acceptedByName: null,
      acceptedAt: null,
      reopenedByUid: null,
      reopenedByName: null,
      reopenedAt: null,
      notApplicableByUid: null,
      notApplicableByName: null,
      notApplicableAt: null,
      isDeleted: false,
      deletedAt: null,
      deletedByUid: null,
      deletedByName: null,
      deleteReason: null,
      version: 1,
      metadataJson: JSON.stringify({
        source: "server_governed_published_template_assignment",
        requestId: request.requestId,
        publicationAuditId,
        packageFirestoreId: request.packageId,
        versionFirestoreId: request.versionId,
        versionNumber: request.expectedVersionNumber,
        contentHash: request.expectedContentHash,
        moduleIndex: index,
      }),
    };
    return {id: moduleId, data};
  });

  execution.modulePopulationLastModuleId =
    modules.length > 0 ? modules[modules.length - 1].id : null;

  return {executionId, execution, modules};
}

async function replayExistingAssignment(args: {
  transaction: AssignmentTransactionLike;
  db: AssignmentFirestoreLike;
  request: ParsedAssignmentRequest;
  actorUid: string;
  requestData: AssignmentJsonMap;
}): Promise<PublishedTemplateAssignmentResult> {
  const {transaction, db, request, actorUid, requestData} = args;
  if (cleanOptionalText(requestData.actorUid) !== actorUid) {
    throw new AssignmentValidationError(
      "already-exists",
      "This request identity is already owned by another user.",
      {reasonCode: "request-owner-mismatch"},
    );
  }
  if (
    cleanOptionalText(requestData.payloadFingerprint) !==
    request.payloadFingerprint
  ) {
    throw new AssignmentValidationError(
      "already-exists",
      "This request identity is already bound to different assignment content.",
      {reasonCode: "request-payload-mismatch"},
    );
  }

  const executionId = assertDocumentId(
    requestData.executionId,
    "stored executionId",
  );
  const moduleIdsRaw = requestData.moduleIds;
  if (
    !Array.isArray(moduleIdsRaw) ||
    moduleIdsRaw.length === 0 ||
    moduleIdsRaw.some((item) => typeof item !== "string")
  ) {
    throw new AssignmentValidationError(
      "data-loss",
      "Stored assignment idempotency evidence is incomplete.",
      {reasonCode: "request-evidence-incomplete"},
    );
  }
  const moduleIds = moduleIdsRaw.map((item) =>
    assertDocumentId(item, "stored moduleId"),
  );
  const executionRef = db.collection("job_executions").doc(executionId);
  const moduleRefs = moduleIds.map((id) =>
    db.collection("job_modules").doc(id),
  );

  const executionSnapshot = await transaction.get(executionRef);
  if ("docs" in executionSnapshot || !executionSnapshot.exists) {
    throw new AssignmentValidationError(
      "data-loss",
      "The idempotent assignment execution record is missing.",
      {reasonCode: "execution-missing-after-assignment", executionId},
    );
  }
  const execution: AssignmentJsonMap = {
    ...(executionSnapshot.data() ?? {}),
    firestoreId: executionId,
  };

  const modules: AssignmentJsonMap[] = [];
  for (let index = 0; index < moduleRefs.length; index += 1) {
    const snapshot = await transaction.get(moduleRefs[index]);
    if ("docs" in snapshot || !snapshot.exists) {
      throw new AssignmentValidationError(
        "data-loss",
        "An idempotent assignment module record is missing.",
        {
          reasonCode: "module-missing-after-assignment",
          moduleId: moduleIds[index],
        },
      );
    }
    modules.push({
      ...(snapshot.data() ?? {}),
      firestoreId: moduleIds[index],
    });
  }

  return {
    ok: true,
    requestId: request.requestId,
    idempotentReplay: true,
    publicationAuditId: assertDocumentId(
      requestData.publicationAuditId,
      "stored publicationAuditId",
    ),
    assignedAt: assertReplayAssignedAt(
      requestData.assignedAt,
      execution.createdAt,
    ),
    executionId,
    execution,
    modules,
  };
}

export async function assignPublishedTemplateVersionWithDb(args: {
  db: AssignmentFirestoreLike;
  authUid: string | null;
  data: AssignmentJsonMap;
  now?: () => Date;
  beforeAssignmentTransactionForTest?: () => Promise<void>;
  beforeAssignmentWritesForTest?: () => Promise<void>;
}): Promise<PublishedTemplateAssignmentResult> {
  const {db, authUid, data} = args;
  if (authUid == null || authUid.trim().length === 0) {
    throw new AssignmentValidationError(
      "unauthenticated",
      "Sign in before assigning a governed job.",
    );
  }
  const actorUid = authUid.trim();
  const request = parsePublishedTemplateAssignmentRequest(data);
  const now = args.now ?? (() => new Date());

  const userRef = db.collection("users").doc(actorUid);
  const requestRef = db
    .collection("published_template_assignment_requests")
    .doc(request.requestId);

  authorizedAssignmentActorData(await userRef.get());

  let lastRefreshDetails: unknown = null;
  let lastTransientTransactionDetails: unknown = null;
  let equipmentRefreshAttempts = 0;
  let transientTransactionAttempts = 0;
  let totalAttempts = 0;
  while (true) {
    totalAttempts += 1;
    const requestReceiptPreflight = await requestRef.get();
    const receiptObservedBeforeTransaction =
      requestReceiptPreflight.exists;
    const workflowFacts = receiptObservedBeforeTransaction
      ? null
      : await loadOpenWorkflowFacts(db, request);
    if (totalAttempts === 1 && args.beforeAssignmentTransactionForTest != null) {
      await args.beforeAssignmentTransactionForTest();
    }

    try {
      return await db.runTransaction(async (transaction) => {
    const userData = authorizedAssignmentActorData(
      await transaction.get(userRef),
    );

    const existingRequestSnapshot = await transaction.get(requestRef);
    if ("docs" in existingRequestSnapshot) {
      throw new AssignmentValidationError(
        "internal",
        "Idempotency lookup returned an invalid response.",
      );
    }
    if (existingRequestSnapshot.exists) {
      return replayExistingAssignment({
        transaction,
        db,
        request,
        actorUid,
        requestData: existingRequestSnapshot.data() ?? {},
      });
    }
    if (receiptObservedBeforeTransaction) {
      throw new AssignmentValidationError(
        "aborted",
        "The assignment request receipt disappeared before transactional replay.",
        {reasonCode: "request-receipt-disappeared"},
      );
    }
    if (workflowFacts == null) {
      throw new AssignmentValidationError(
        "internal",
        "Workflow facts were not loaded for a new assignment.",
      );
    }

    const packageRef = db
      .collection("template_packages")
      .doc(request.packageId);
    const versionRef = db
      .collection("template_versions")
      .doc(request.versionId);
    const auditQuery = db
      .collection("template_publish_audits")
      .where("versionFirestoreId", "==", request.versionId);

    const packageSnapshot = await transaction.get(packageRef);
    const versionSnapshot = await transaction.get(versionRef);
    const auditSnapshot = await transaction.get(auditQuery);

    if ("docs" in packageSnapshot || "docs" in versionSnapshot) {
      throw new AssignmentValidationError(
        "internal",
        "Governance document lookup returned an invalid response.",
      );
    }
    const packageData = snapshotData(
      packageSnapshot,
      "TemplatePackage",
    );
    const versionData = snapshotData(
      versionSnapshot,
      "TemplateVersion",
    );

    if (
      cleanOptionalText(packageData.firestoreId) !== request.packageId
    ) {
      throw new AssignmentValidationError(
        "failed-precondition",
        "The TemplatePackage identity does not match its document identity.",
        {reasonCode: "package-identity-mismatch"},
      );
    }
    if (
      cleanOptionalText(versionData.firestoreId) !== request.versionId
    ) {
      throw new AssignmentValidationError(
        "failed-precondition",
        "The TemplateVersion identity does not match its document identity.",
        {reasonCode: "version-identity-mismatch"},
      );
    }
    if (
      packageData.isDeleted === true ||
      packageData.lifecycleStatus !== "active"
    ) {
      throw new AssignmentValidationError(
        "failed-precondition",
        "Only an active, non-deleted TemplatePackage can be assigned.",
        {reasonCode: "package-not-active"},
      );
    }
    if (
      cleanOptionalText(packageData.activeVersionFirestoreId) !==
      request.versionId
    ) {
      throw new AssignmentValidationError(
        "failed-precondition",
        "The selected TemplateVersion is no longer the package active version.",
        {reasonCode: "version-not-active"},
      );
    }
    if (
      versionData.isDeleted === true ||
      versionData.status !== "published"
    ) {
      throw new AssignmentValidationError(
        "failed-precondition",
        "Only a published, non-deleted TemplateVersion can be assigned.",
        {reasonCode: "version-not-published"},
      );
    }
    if (
      cleanOptionalText(versionData.packageFirestoreId) !==
      request.packageId
    ) {
      throw new AssignmentValidationError(
        "failed-precondition",
        "The selected TemplateVersion does not belong to the active package.",
        {reasonCode: "version-package-mismatch"},
      );
    }
    if (
      packageData.latestVersionNumber !== request.expectedVersionNumber
    ) {
      throw new AssignmentValidationError(
        "failed-precondition",
        "The active package version number does not match its active TemplateVersion.",
        {
          reasonCode: "package-version-number-mismatch",
          packageLatestVersionNumber: packageData.latestVersionNumber,
          expectedVersionNumber: request.expectedVersionNumber,
        },
      );
    }
    if (
      versionData.versionNumber !== request.expectedVersionNumber
    ) {
      throw new AssignmentValidationError(
        "aborted",
        "The active TemplateVersion number changed. Pull latest governance data and retry.",
        {
          reasonCode: "version-number-changed",
          expected: request.expectedVersionNumber,
          actual: versionData.versionNumber,
        },
      );
    }
    const storedHash = cleanOptionalText(versionData.contentHash);
    if (storedHash !== request.expectedContentHash) {
      throw new AssignmentValidationError(
        "aborted",
        "The active TemplateVersion content hash changed. Pull latest governance data and retry.",
        {
          reasonCode: "version-hash-changed",
          expected: request.expectedContentHash,
          actual: storedHash,
        },
      );
    }
    if (
      typeof storedHash !== "string" ||
      !CONTENT_HASH_PATTERN.test(storedHash)
    ) {
      throw new AssignmentValidationError(
        "failed-precondition",
        "The active TemplateVersion has no valid governed content hash.",
        {reasonCode: "version-hash-invalid"},
      );
    }

    const computedHash = computeTemplateVersionContentHash(versionData);
    if (computedHash !== storedHash) {
      throw new AssignmentValidationError(
        "failed-precondition",
        "The active TemplateVersion payload does not match its governed content hash.",
        {
          reasonCode: "version-hash-mismatch",
          storedHash,
          computedHash,
        },
      );
    }

    const publishedByUid = cleanOptionalText(
      versionData.publishedByUid,
    );
    if (publishedByUid == null) {
      throw new AssignmentValidationError(
        "failed-precondition",
        "The published TemplateVersion is missing its publishing actor.",
        {reasonCode: "published-actor-missing"},
      );
    }

    const publicationAudit = selectPublicationAudit(
      queryDocs(auditSnapshot),
      request.packageId,
      request.versionId,
      storedHash,
      publishedByUid,
    );

    const assignedAt = now().toISOString();
    const actorName =
      cleanOptionalText(userData.name) ??
      cleanOptionalText(userData.email);
    const canonical = buildCanonicalAssignment({
      db,
      request,
      actorUid,
      actorName,
      packageData,
      versionData,
      publicationAuditId: publicationAudit.id,
      assignedAt,
    });

    const executionRef = db
      .collection("job_executions")
      .doc(canonical.executionId);
    const workflowRef = db
      .collection("maintenance_workflows")
      .doc(canonical.executionId);
    const equipmentRef = db
      .collection("equipment_status")
      .doc(`${request.assetType}_${request.assetNumber}`);
    const equipmentSnapshot = await transaction.get(equipmentRef);
    if ("docs" in equipmentSnapshot) {
      throw new AssignmentValidationError("internal", "Equipment lookup returned an invalid response.");
    }
    const equipmentProjection = serializedEquipmentProjection(
      equipmentSnapshot,
      request,
      workflowFacts,
    );
    const activeNonRedMaintenanceCount =
      equipmentProjection.activeNonRedMaintenanceCount + 1;
    const activeRedWorkCount = equipmentProjection.activeRedWorkCount;
    const awaitingPreparationCount =
      equipmentProjection.awaitingPreparationCount;
    const equipmentState = activeRedWorkCount > 0
      ? "underRED"
      : awaitingPreparationCount > 0
        ? "awaitingPreparation"
        : "underMaintenance";
    const equipmentData = equipmentProjection.data;
    const previousEquipmentState =
      cleanOptionalText(equipmentData.state) ??
      equipmentStateFromFacts(workflowFacts) ??
      "inService";
    if (args.beforeAssignmentWritesForTest != null) {
      await args.beforeAssignmentWritesForTest();
    }

    transaction.set(executionRef, canonical.execution);
    transaction.set(workflowRef, {
      jobExecutionId: canonical.executionId,
      assetTypeKey: request.assetType,
      assetNumber: request.assetNumber,
      status: "pendingLaneClassification",
      version: 1,
      workflowSchemaVersion: 1,
      laneSetVersion: 0,
      laneSetFinalizedAt: null,
      activeRedWork: false,
      awaitingPreparation: false,
      cancelled: false,
      createdByUid: actorUid,
      createdByName: actorName,
      createdAt: assignedAt,
      updatedAt: assignedAt,
    });
    transaction.set(equipmentRef, {
      assetTypeKey: request.assetType,
      assetNumber: request.assetNumber,
      previousState: previousEquipmentState,
      state: equipmentState,
      activeNonRedMaintenanceCount,
      activeRedWorkCount,
      awaitingPreparationCount,
      transitionTrigger: `governedAssignment:${canonical.executionId}`,
      lastTransitionAt: assignedAt,
      lastTransitionByUid: actorUid,
      lastTransitionByName: actorName,
      availableSince: null,
      inServiceSince: null,
      version: equipmentProjection.version + 1,
      updatedAt: assignedAt,
    }, {merge: true});
    for (const module of canonical.modules) {
      transaction.set(
        db.collection("job_modules").doc(module.id),
        module.data,
      );
    }
    transaction.set(requestRef, {
      firestoreId: request.requestId,
      actorUid,
      payloadFingerprint: request.payloadFingerprint,
      packageId: request.packageId,
      versionId: request.versionId,
      versionNumber: request.expectedVersionNumber,
      contentHash: request.expectedContentHash,
      publicationAuditId: publicationAudit.id,
      executionId: canonical.executionId,
      moduleIds: canonical.modules.map((module) => module.id),
      assignedAt,
      createdAt: assignedAt,
      status: "completed",
      schemaVersion: 1,
    });

    return {
      ok: true,
      requestId: request.requestId,
      idempotentReplay: false,
      publicationAuditId: publicationAudit.id,
      assignedAt,
      executionId: canonical.executionId,
      execution: canonical.execution,
      modules: canonical.modules.map((module) => module.data),
    };
      });
    } catch (error) {
      const reasonCode = assignmentReasonCode(error);
      if (reasonCode === "equipment-projection-refresh-required") {
        equipmentRefreshAttempts += 1;
        lastRefreshDetails = error instanceof AssignmentValidationError
          ? error.details
          : null;
        if (
          equipmentRefreshAttempts >=
          MAX_EQUIPMENT_PROJECTION_RECONCILIATION_ATTEMPTS
        ) {
          throw new AssignmentValidationError(
            "failed-precondition",
            "The equipment projection and workflow facts did not converge after bounded reconciliation.",
            {
              reasonCode: "equipment-projection-reconciliation-exhausted",
              maximumAttempts:
                MAX_EQUIPMENT_PROJECTION_RECONCILIATION_ATTEMPTS,
              lastRefreshDetails,
            },
          );
        }
        continue;
      }
      if (isRetryableClosedTransactionError(error)) {
        transientTransactionAttempts += 1;
        lastTransientTransactionDetails = {
          attempt: totalAttempts,
          transientAttempt: transientTransactionAttempts,
          code: (error as {code?: unknown}).code ?? null,
          message: error instanceof Error ? error.message : String(error),
          details: (error as {details?: unknown}).details ?? null,
        };
        if (
          transientTransactionAttempts >=
          MAX_ASSIGNMENT_TRANSACTION_ATTEMPTS
        ) {
          throw new AssignmentValidationError(
            "aborted",
            "The assignment transaction did not stabilize after bounded retry.",
            {
              reasonCode: "assignment-transaction-retry-exhausted",
              maximumAttempts: MAX_ASSIGNMENT_TRANSACTION_ATTEMPTS,
              lastTransientTransactionDetails,
            },
          );
        }
        continue;
      }
      throw error;
    }
  }
}
